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
    fields: { [string]: MachinaFieldType }?,
}

export type MachinaSystemPhase = "startup" | "update" | "fixed_update" | "render"

export type MachinaVec3 = { number }

export type MachinaSchemaValue = MachinaVec3

export type MachinaSchemaComponentDefinition<T> = {
    version: number?,
    fields: T,
}

export type MachinaComponent<T> = {
    id: MachinaComponentId,

    --- Runtime-guarded type brand used by Luau to preserve component payload types through handles.
    __machina_component_type: () -> T,
}

export type MachinaComponentRef = MachinaComponentId | MachinaComponent<any>
export type MachinaComponentRefs = { MachinaComponentId }
export type MachinaQueryRef = {
    refs: MachinaComponentRefs,
}

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

export type MachinaWorldQueryFunction =
    (<A>(MachinaComponent<A>) -> (() -> (MachinaEntity, A)))
    & (<A, B>(MachinaComponent<A>, MachinaComponent<B>) -> (() -> (MachinaEntity, A, B)))
    & (<A, B, C>(MachinaComponent<A>, MachinaComponent<B>, MachinaComponent<C>) -> (() -> (MachinaEntity, A, B, C)))
    & (<A, B, C, D>(MachinaComponent<A>, MachinaComponent<B>, MachinaComponent<C>, MachinaComponent<D>) -> (() -> (MachinaEntity, A, B, C, D)))
    & (<A, B, C, D, E>(MachinaComponent<A>, MachinaComponent<B>, MachinaComponent<C>, MachinaComponent<D>, MachinaComponent<E>) -> (() -> (MachinaEntity, A, B, C, D, E)))
    & (<A, B, C, D, E, F>(MachinaComponent<A>, MachinaComponent<B>, MachinaComponent<C>, MachinaComponent<D>, MachinaComponent<E>, MachinaComponent<F>) -> (() -> (MachinaEntity, A, B, C, D, E, F)))
    & ((...MachinaComponentId) -> (() -> MachinaEntity))

export type MachinaWorld = {
    --- Iterates entities that have all requested components.
    query: MachinaWorldQueryFunction,
}

export type MachinaQueryObject1<A> = {
    refs: MachinaComponentRefs,
    iter: (self: MachinaQueryObject1<A>, world: MachinaWorld) -> (() -> (MachinaEntity, A)),
}

export type MachinaQueryObject2<A, B> = {
    refs: MachinaComponentRefs,
    iter: (self: MachinaQueryObject2<A, B>, world: MachinaWorld) -> (() -> (MachinaEntity, A, B)),
}

export type MachinaQueryObject3<A, B, C> = {
    refs: MachinaComponentRefs,
    iter: (self: MachinaQueryObject3<A, B, C>, world: MachinaWorld) -> (() -> (MachinaEntity, A, B, C)),
}

export type MachinaQueryObject4<A, B, C, D> = {
    refs: MachinaComponentRefs,
    iter: (self: MachinaQueryObject4<A, B, C, D>, world: MachinaWorld) -> (() -> (MachinaEntity, A, B, C, D)),
}

export type MachinaQueryObject5<A, B, C, D, E> = {
    refs: MachinaComponentRefs,
    iter: (self: MachinaQueryObject5<A, B, C, D, E>, world: MachinaWorld) -> (() -> (MachinaEntity, A, B, C, D, E)),
}

export type MachinaQueryObject6<A, B, C, D, E, F> = {
    refs: MachinaComponentRefs,
    iter: (self: MachinaQueryObject6<A, B, C, D, E, F>, world: MachinaWorld) -> (() -> (MachinaEntity, A, B, C, D, E, F)),
}

export type MachinaSystemDefinition = {
    phase: MachinaSystemPhase?,
    query: MachinaQueryRef?,
    reads: MachinaComponentRefs?,
    writes: MachinaComponentRefs?,
    before: { MachinaSystemId }?,
    after: { MachinaSystemId }?,
    run: ((world: MachinaWorld, delta_seconds: number) -> ())?,
}

export type MachinaComponentFunction = <T>(
    id: MachinaComponentId,
    definition: (MachinaComponentDefinition | MachinaSchemaComponentDefinition<T>)?
) -> MachinaComponent<T>

export type MachinaFieldsFunction = (
    fields: { [string]: MachinaFieldType }
) -> { [string]: MachinaFieldType }

export type MachinaSchemaFunction = <T>(
    fields: T & { [string]: MachinaSchemaValue }
) -> T

export type MachinaQueryFunction =
    (<A>(MachinaComponent<A>) -> MachinaQueryObject1<A>)
    & (<A, B>(MachinaComponent<A>, MachinaComponent<B>) -> MachinaQueryObject2<A, B>)
    & (<A, B, C>(MachinaComponent<A>, MachinaComponent<B>, MachinaComponent<C>) -> MachinaQueryObject3<A, B, C>)
    & (<A, B, C, D>(MachinaComponent<A>, MachinaComponent<B>, MachinaComponent<C>, MachinaComponent<D>) -> MachinaQueryObject4<A, B, C, D>)
    & (<A, B, C, D, E>(MachinaComponent<A>, MachinaComponent<B>, MachinaComponent<C>, MachinaComponent<D>, MachinaComponent<E>) -> MachinaQueryObject5<A, B, C, D, E>)
    & (<A, B, C, D, E, F>(MachinaComponent<A>, MachinaComponent<B>, MachinaComponent<C>, MachinaComponent<D>, MachinaComponent<E>, MachinaComponent<F>) -> MachinaQueryObject6<A, B, C, D, E, F>)
    & ((...MachinaComponentId) -> MachinaQueryRef)

export type MachinaEcs = {
    --- Registers a project-local component type or returns a typed handle for an existing component.
    component: MachinaComponentFunction,

    --- Creates a reusable query object over typed component handles.
    query: MachinaQueryFunction,

    --- Validates and preserves typed component field declaration maps.
    fields: MachinaFieldsFunction,

    --- Infers component payload types from schema marker fields.
    schema: MachinaSchemaFunction,

    --- Declares a vec3 field in an inferred component schema.
    vec3: () -> MachinaVec3,

    --- Erases typed component handles into component id refs for system read/write declarations.
    refs: (...MachinaComponentRef) -> MachinaComponentRefs,

    --- Registers a project-local system type.
    system: (id: MachinaSystemId, definition: MachinaSystemDefinition) -> (),
}

declare ecs: MachinaEcs
