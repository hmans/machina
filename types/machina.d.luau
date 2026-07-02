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

type MachinaComponent<T> = {
    id: MachinaComponentId,
}

type MachinaComponentRef = MachinaComponentId | MachinaComponent<any>

type MachinaTransform = {
    position: MachinaVec3,
    rotation: MachinaVec3,
    scale: MachinaVec3,
}

type MachinaRenderCube = {
    color: MachinaVec3,
}

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

type MachinaQuery =
    (<A>(MachinaComponent<A>) -> (() -> (MachinaEntity, A)))
    & (<A, B>(MachinaComponent<A>, MachinaComponent<B>) -> (() -> (MachinaEntity, A, B)))
    & (<A, B, C>(MachinaComponent<A>, MachinaComponent<B>, MachinaComponent<C>) -> (() -> (MachinaEntity, A, B, C)))
    & ((...MachinaComponentId) -> (() -> MachinaEntity))

type MachinaWorld = {
    --- Iterates entities that have all requested components.
    query: MachinaQuery,
}

type MachinaSystemDefinition = {
    phase: MachinaSystemPhase?,
    reads: { MachinaComponentRef }?,
    writes: { MachinaComponentRef }?,
    before: { MachinaSystemId }?,
    after: { MachinaSystemId }?,
    run: ((world: MachinaWorld, delta_seconds: number) -> ())?,
}

type MachinaComponentFunction = <T>(
    id: MachinaComponentId,
    definition: MachinaComponentDefinition?
) -> MachinaComponent<T>

type MachinaEcs = {
    --- Registers a project-local component type or returns a typed handle for an existing component.
    component: MachinaComponentFunction,

    --- Registers a project-local system type.
    system: (id: MachinaSystemId, definition: MachinaSystemDefinition) -> (),
}

declare ecs: MachinaEcs
