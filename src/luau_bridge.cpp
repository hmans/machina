#include "luau_bridge.h"

#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>

#include "lua.h"
#include "lualib.h"
#include "luacode.h"

struct ComponentField
{
    std::string name;
    std::string type;
};

struct ComponentDecl
{
    std::string id;
    uint32_t version = 1;
    std::vector<ComponentField> fields;
};

struct SystemDecl
{
    std::string id;
    std::string phase = "update";
    std::vector<std::string> reads;
    std::vector<std::string> writes;
    std::vector<std::string> before;
    std::vector<std::string> after;
    uint32_t runner_ref = 0;
};

struct machina_luau
{
    lua_State* state = nullptr;
    machina_luau_callbacks callbacks = {};
    void* callback_context = nullptr;
    void* active_world = nullptr;
    std::vector<ComponentDecl> components;
    std::vector<SystemDecl> systems;
    std::string last_error;
};

static machina_luau* vm_from_upvalue(lua_State* state)
{
    return static_cast<machina_luau*>(lua_tolightuserdata(state, lua_upvalueindex(1)));
}

static void set_error(machina_luau* vm, const char* message)
{
    vm->last_error = message ? message : "unknown Luau error";
}

static std::string check_string(lua_State* state, int index)
{
    size_t len = 0;
    const char* value = luaL_checklstring(state, index, &len);
    return std::string(value, len);
}

static bool read_optional_string_field(lua_State* state, int table_index, const char* key, std::string* out)
{
    lua_getfield(state, table_index, key);
    if (lua_isnil(state, -1))
    {
        lua_pop(state, 1);
        return false;
    }

    size_t len = 0;
    const char* value = luaL_checklstring(state, -1, &len);
    out->assign(value, len);
    lua_pop(state, 1);
    return true;
}

static uint32_t read_optional_u32_field(lua_State* state, int table_index, const char* key, uint32_t fallback)
{
    lua_getfield(state, table_index, key);
    if (lua_isnil(state, -1))
    {
        lua_pop(state, 1);
        return fallback;
    }

    const int value = luaL_checkinteger(state, -1);
    lua_pop(state, 1);
    return value < 0 ? fallback : static_cast<uint32_t>(value);
}

static std::vector<std::string> read_string_array(lua_State* state, int table_index)
{
    std::vector<std::string> values;
    const int count = lua_objlen(state, table_index);
    values.reserve(count);

    for (int i = 1; i <= count; ++i)
    {
        lua_rawgeti(state, table_index, i);
        size_t len = 0;
        const char* value = luaL_checklstring(state, -1, &len);
        values.emplace_back(value, len);
        lua_pop(state, 1);
    }

    return values;
}

static std::vector<std::string> read_optional_string_array_field(lua_State* state, int table_index, const char* key)
{
    lua_getfield(state, table_index, key);
    if (lua_isnil(state, -1))
    {
        lua_pop(state, 1);
        return {};
    }

    luaL_checktype(state, -1, LUA_TTABLE);
    const int array_index = lua_absindex(state, -1);
    std::vector<std::string> values = read_string_array(state, array_index);
    lua_pop(state, 1);
    return values;
}

static int ecs_component(lua_State* state)
{
    machina_luau* vm = vm_from_upvalue(state);
    ComponentDecl component;
    component.id = check_string(state, 1);

    if (!lua_isnoneornil(state, 2))
    {
        luaL_checktype(state, 2, LUA_TTABLE);
        const int definition_index = lua_absindex(state, 2);
        component.version = read_optional_u32_field(state, definition_index, "version", 1);

        lua_getfield(state, definition_index, "fields");
        if (!lua_isnil(state, -1))
        {
            luaL_checktype(state, -1, LUA_TTABLE);
            const int fields_index = lua_absindex(state, -1);
            lua_pushnil(state);
            while (lua_next(state, fields_index) != 0)
            {
                size_t name_len = 0;
                size_t type_len = 0;
                const char* name = luaL_checklstring(state, -2, &name_len);
                const char* type = luaL_checklstring(state, -1, &type_len);
                component.fields.push_back({
                    std::string(name, name_len),
                    std::string(type, type_len),
                });
                lua_pop(state, 1);
            }
        }
        lua_pop(state, 1);
    }

    vm->components.push_back(std::move(component));
    return 0;
}

static int ecs_system(lua_State* state)
{
    machina_luau* vm = vm_from_upvalue(state);
    SystemDecl system;
    system.id = check_string(state, 1);

    if (!lua_isnoneornil(state, 2))
    {
        luaL_checktype(state, 2, LUA_TTABLE);
        const int definition_index = lua_absindex(state, 2);
        read_optional_string_field(state, definition_index, "phase", &system.phase);
        system.reads = read_optional_string_array_field(state, definition_index, "reads");
        system.writes = read_optional_string_array_field(state, definition_index, "writes");
        system.before = read_optional_string_array_field(state, definition_index, "before");
        system.after = read_optional_string_array_field(state, definition_index, "after");

        lua_getfield(state, definition_index, "run");
        if (!lua_isnil(state, -1))
        {
            luaL_checktype(state, -1, LUA_TFUNCTION);
            system.runner_ref = static_cast<uint32_t>(lua_ref(state, -1));
        }
        lua_pop(state, 1);
    }

    vm->systems.push_back(std::move(system));
    return 0;
}

static int world_rotate(lua_State* state)
{
    machina_luau* vm = vm_from_upvalue(state);
    const char* transform_id = luaL_checkstring(state, 1);
    const char* spin_id = luaL_checkstring(state, 2);
    const double delta_seconds = luaL_checknumber(state, 3);

    if (!vm->callbacks.rotate || !vm->callbacks.rotate(vm->callback_context, vm->active_world, transform_id, spin_id, delta_seconds))
        luaL_error(state, "world.rotate access denied or failed");

    return 0;
}

static void install_ecs(lua_State* state, machina_luau* vm)
{
    lua_newtable(state);

    lua_pushlightuserdata(state, vm);
    lua_pushcclosure(state, ecs_component, "ecs.component", 1);
    lua_setfield(state, -2, "component");

    lua_pushlightuserdata(state, vm);
    lua_pushcclosure(state, ecs_system, "ecs.system", 1);
    lua_setfield(state, -2, "system");

    lua_setreadonly(state, -1, 1);
    lua_setglobal(state, "ecs");
}

static void push_world(lua_State* state, machina_luau* vm)
{
    lua_newtable(state);
    lua_pushlightuserdata(state, vm);
    lua_pushcclosure(state, world_rotate, "world.rotate", 1);
    lua_setfield(state, -2, "rotate");
    lua_setreadonly(state, -1, 1);
}

machina_luau* machina_luau_create(machina_luau_callbacks callbacks)
{
    machina_luau* vm = new machina_luau();
    vm->callbacks = callbacks;
    vm->state = luaL_newstate();
    if (!vm->state)
    {
        set_error(vm, "failed to create Luau state");
        return vm;
    }

    luaL_openlibs(vm->state);
    install_ecs(vm->state, vm);
    luaL_sandbox(vm->state);
    return vm;
}

void machina_luau_destroy(machina_luau* vm)
{
    if (!vm)
        return;

    if (vm->state)
        lua_close(vm->state);
    delete vm;
}

void machina_luau_set_callback_context(machina_luau* vm, void* context)
{
    if (vm)
        vm->callback_context = context;
}

int machina_luau_load(machina_luau* vm, const char* chunk_name, const char* source, size_t source_len)
{
    if (!vm || !vm->state)
        return 0;

    vm->last_error.clear();

    size_t bytecode_size = 0;
    char* bytecode = luau_compile(source, source_len, nullptr, &bytecode_size);
    if (!bytecode)
    {
        set_error(vm, "failed to compile Luau source");
        return 0;
    }

    lua_State* thread = lua_newthread(vm->state);
    luaL_sandboxthread(thread);

    int status = luau_load(thread, chunk_name, bytecode, bytecode_size, 0);
    std::free(bytecode);
    if (status == LUA_OK)
        status = lua_resume(thread, nullptr, 0);

    if (status != LUA_OK)
    {
        set_error(vm, lua_tostring(thread, -1));
        lua_pop(vm->state, 1);
        return 0;
    }

    lua_pop(vm->state, 1);
    return 1;
}

const char* machina_luau_last_error(const machina_luau* vm)
{
    return vm ? vm->last_error.c_str() : "missing Luau VM";
}

size_t machina_luau_component_count(const machina_luau* vm)
{
    return vm ? vm->components.size() : 0;
}

const char* machina_luau_component_id(const machina_luau* vm, size_t component_index)
{
    return vm && component_index < vm->components.size() ? vm->components[component_index].id.c_str() : nullptr;
}

uint32_t machina_luau_component_version(const machina_luau* vm, size_t component_index)
{
    return vm && component_index < vm->components.size() ? vm->components[component_index].version : 1;
}

size_t machina_luau_component_field_count(const machina_luau* vm, size_t component_index)
{
    return vm && component_index < vm->components.size() ? vm->components[component_index].fields.size() : 0;
}

const char* machina_luau_component_field_name(const machina_luau* vm, size_t component_index, size_t field_index)
{
    if (!vm || component_index >= vm->components.size() || field_index >= vm->components[component_index].fields.size())
        return nullptr;
    return vm->components[component_index].fields[field_index].name.c_str();
}

const char* machina_luau_component_field_type(const machina_luau* vm, size_t component_index, size_t field_index)
{
    if (!vm || component_index >= vm->components.size() || field_index >= vm->components[component_index].fields.size())
        return nullptr;
    return vm->components[component_index].fields[field_index].type.c_str();
}

size_t machina_luau_system_count(const machina_luau* vm)
{
    return vm ? vm->systems.size() : 0;
}

const char* machina_luau_system_id(const machina_luau* vm, size_t system_index)
{
    return vm && system_index < vm->systems.size() ? vm->systems[system_index].id.c_str() : nullptr;
}

const char* machina_luau_system_phase(const machina_luau* vm, size_t system_index)
{
    return vm && system_index < vm->systems.size() ? vm->systems[system_index].phase.c_str() : nullptr;
}

uint32_t machina_luau_system_runner_ref(const machina_luau* vm, size_t system_index)
{
    return vm && system_index < vm->systems.size() ? vm->systems[system_index].runner_ref : 0;
}

static size_t string_list_count(const std::vector<std::string>* values)
{
    return values ? values->size() : 0;
}

static const char* string_list_item(const std::vector<std::string>* values, size_t item_index)
{
    return values && item_index < values->size() ? (*values)[item_index].c_str() : nullptr;
}

static const std::vector<std::string>* system_reads(const machina_luau* vm, size_t system_index)
{
    return vm && system_index < vm->systems.size() ? &vm->systems[system_index].reads : nullptr;
}

static const std::vector<std::string>* system_writes(const machina_luau* vm, size_t system_index)
{
    return vm && system_index < vm->systems.size() ? &vm->systems[system_index].writes : nullptr;
}

static const std::vector<std::string>* system_before(const machina_luau* vm, size_t system_index)
{
    return vm && system_index < vm->systems.size() ? &vm->systems[system_index].before : nullptr;
}

static const std::vector<std::string>* system_after(const machina_luau* vm, size_t system_index)
{
    return vm && system_index < vm->systems.size() ? &vm->systems[system_index].after : nullptr;
}

size_t machina_luau_system_reads_count(const machina_luau* vm, size_t system_index)
{
    return string_list_count(system_reads(vm, system_index));
}

const char* machina_luau_system_reads_item(const machina_luau* vm, size_t system_index, size_t item_index)
{
    return string_list_item(system_reads(vm, system_index), item_index);
}

size_t machina_luau_system_writes_count(const machina_luau* vm, size_t system_index)
{
    return string_list_count(system_writes(vm, system_index));
}

const char* machina_luau_system_writes_item(const machina_luau* vm, size_t system_index, size_t item_index)
{
    return string_list_item(system_writes(vm, system_index), item_index);
}

size_t machina_luau_system_before_count(const machina_luau* vm, size_t system_index)
{
    return string_list_count(system_before(vm, system_index));
}

const char* machina_luau_system_before_item(const machina_luau* vm, size_t system_index, size_t item_index)
{
    return string_list_item(system_before(vm, system_index), item_index);
}

size_t machina_luau_system_after_count(const machina_luau* vm, size_t system_index)
{
    return string_list_count(system_after(vm, system_index));
}

const char* machina_luau_system_after_item(const machina_luau* vm, size_t system_index, size_t item_index)
{
    return string_list_item(system_after(vm, system_index), item_index);
}

int machina_luau_call_system(machina_luau* vm, uint32_t runner_ref, void* world, double delta_seconds)
{
    if (!vm || !vm->state || runner_ref == 0)
        return 1;

    vm->last_error.clear();
    vm->active_world = world;
    lua_getref(vm->state, static_cast<int>(runner_ref));
    if (!lua_isfunction(vm->state, -1))
    {
        lua_pop(vm->state, 1);
        vm->active_world = nullptr;
        set_error(vm, "system runner reference is not a function");
        return 0;
    }

    push_world(vm->state, vm);
    lua_pushnumber(vm->state, delta_seconds);
    const int status = lua_pcall(vm->state, 2, 0, 0);
    vm->active_world = nullptr;

    if (status != LUA_OK)
    {
        set_error(vm, lua_tostring(vm->state, -1));
        lua_pop(vm->state, 1);
        return 0;
    }

    return 1;
}
