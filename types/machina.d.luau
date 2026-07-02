export type MachinaComponentId = string
export type MachinaSystemId = string

export type MachinaFieldType =
    "boolean"
    | "bool"
    | "int"
    | "i32"
    | "float"
    | "f32"
    | "vec3"
    | "string"

export type MachinaComponentDefinition = {
    version: number?,
    fields: { [string]: string }?,
}

export type MachinaSystemPhase = "startup" | "update" | "fixed_update" | "render"

export type MachinaVec3 = { number }

export type MachinaComponent<T> = {
    id: MachinaComponentId,

    --- Type-only marker used by Luau to preserve component payload types through handles.
    __machina_component_type: T,
}

export type MachinaComponentRef = MachinaComponentId | MachinaComponent<any>
export type MachinaComponentRefs = { MachinaComponentId }

export type MachinaTransform = {
    position: MachinaVec3,
    rotation: MachinaVec3,
    scale: MachinaVec3,
}

export type MachinaRenderCube = {
    color: MachinaVec3,
}

export type MachinaEntity = {
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

export type MachinaQuery =
    (<A>(MachinaComponent<A>) -> (() -> (MachinaEntity, A)))
    & (<A, B>(MachinaComponent<A>, MachinaComponent<B>) -> (() -> (MachinaEntity, A, B)))
    & (<A, B, C>(MachinaComponent<A>, MachinaComponent<B>, MachinaComponent<C>) -> (() -> (MachinaEntity, A, B, C)))
    & ((...MachinaComponentId) -> (() -> MachinaEntity))

export type MachinaWorld = {
    --- Iterates entities that have all requested components.
    query: MachinaQuery,
}

export type MachinaSystemDefinition = {
    phase: MachinaSystemPhase?,
    reads: MachinaComponentRefs?,
    writes: MachinaComponentRefs?,
    before: { MachinaSystemId }?,
    after: { MachinaSystemId }?,
    run: ((world: MachinaWorld, delta_seconds: number) -> ())?,
}

export type MachinaComponentFunction = <T>(
    id: MachinaComponentId,
    definition: MachinaComponentDefinition?
) -> MachinaComponent<T>

export type MachinaEcs = {
    --- Registers a project-local component type or returns a typed handle for an existing component.
    component: MachinaComponentFunction,

    --- Erases typed component handles into component id refs for system read/write declarations.
    refs: (...MachinaComponentRef) -> MachinaComponentRefs,

    --- Registers a project-local system type.
    system: (id: MachinaSystemId, definition: MachinaSystemDefinition) -> (),
}

declare ecs: MachinaEcs
