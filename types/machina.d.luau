type MachinaComponentId = string
type MachinaSystemId = string

type MachinaFieldType =
    "boolean"
    | "bool"
    | "int"
    | "i32"
    | "float"
    | "f32"
    | "vec3"
    | "string"

type MachinaComponentDefinition = {
    version: number?,
    fields: { [string]: MachinaFieldType }?,
}

type MachinaSystemPhase = "startup" | "update" | "fixed_update" | "render"

type MachinaVec3 = { number }

type MachinaEntity = {
    get_vec3: (
        component: MachinaComponentId,
        field: string
    ) -> MachinaVec3,

    set_vec3: (
        component: MachinaComponentId,
        field: string,
        value: MachinaVec3
    ) -> (),
}

type MachinaWorld = {
    --- Iterates entities that have all requested components.
    query: (...MachinaComponentId) -> (() -> MachinaEntity?),
}

type MachinaSystemDefinition = {
    phase: MachinaSystemPhase?,
    reads: { MachinaComponentId }?,
    writes: { MachinaComponentId }?,
    before: { MachinaSystemId }?,
    after: { MachinaSystemId }?,
    run: ((world: MachinaWorld, delta_seconds: number) -> ())?,
}

type MachinaEcs = {
    --- Registers a project-local component type.
    component: (id: MachinaComponentId, definition: MachinaComponentDefinition?) -> (),

    --- Registers a project-local system type.
    system: (id: MachinaSystemId, definition: MachinaSystemDefinition) -> (),
}

declare ecs: MachinaEcs
