type MachinaComponentId = string
type MachinaSystemId = string

type MachinaFieldType =
    "boolean"
    | "bool"
    | "int"
    | "i32"
    | "float"
    | "f32"
    | "string"

type MachinaComponentDefinition = {
    version: number?,
    fields: { [string]: MachinaFieldType }?,
}

type MachinaSystemPhase = "startup" | "update" | "fixed_update" | "render"

type MachinaWorld = {
    --- Rotates every entity with the requested transform and spin components.
    rotate: (
        transform: MachinaComponentId,
        spin: MachinaComponentId,
        delta_seconds: number
    ) -> (),
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
