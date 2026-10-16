class_name RoadTrafficVehicles
extends RefCounted

## The road vehicles of the game's dynamic/ directory as RoadTrafficServer drives them: a type per
## vehicle and skin of the categories weighed (MaszynaVehiclesBank), each category's weight shared
## among its types. A type's size and speed are its .fiz's (Dim.L, Dim.W, Vmax) and its model its
## .mmd's `models:` - read by libmaszyna's readers, as a rail vehicle's are
## (MaszynaRailVehicle3DInstancer.read_structure()).


## The types of the vehicles under `game_dir` (an absolute path) of the categories in `weights`
static func read(game_dir: String, weights: Dictionary[MaszynaVehiclesBank.Category, float]) -> Array[RoadTrafficVehicleType]:
    var by_category: Dictionary[MaszynaVehiclesBank.Category, Array] = {}
    for vehicle: MaszynaVehiclesBank.Vehicle in MaszynaVehiclesBank.scan(game_dir):
        if not weights.has(vehicle.category):
            continue
        var relative_path: String = vehicle.data_path.trim_prefix("/")
        # an index may list a vehicle of no .fiz (dynamic/road/jelcz's "315", its .fiz is 315dumb):
        # it has no size, and the original cannot drive it either
        if not FileAccess.file_exists(game_dir.path_join(
                MaszynaDataPath.resolve(game_dir, relative_path.path_join(vehicle.file_name + ".fiz")))):
            continue
        var description: VehicleController = FizVehicleBuilder.build_description(relative_path, vehicle.file_name)
        var mmd_path: String = game_dir.path_join(
                MaszynaDataPath.resolve(game_dir, relative_path.path_join(vehicle.file_name + ".mmd")))
        for skin: String in vehicle.skins:
            var type: RoadTrafficVehicleType = RoadTrafficVehicleType.new()
            type.data_path = vehicle.data_path
            # the model is named by the .mmd, its .fiz/.mmd base name only without one
            type.model_filename = MmdCabinInstancer.parse_body_model(
                    mmd_path, MmdCabinInstancer.vehicle_parameters("", vehicle.file_name, skin))
            if not type.model_filename:
                type.model_filename = vehicle.file_name
            type.skins = PackedStringArray(MmdCabinInstancer.resolve_skins(vehicle.data_path, skin))
            type.length = description.dimensions_length
            type.width = description.dimensions_width
            type.max_velocity = description.max_velocity
            by_category.get_or_add(vehicle.category, []).append(type)
    var types: Array[RoadTrafficVehicleType] = []
    for category: MaszynaVehiclesBank.Category in by_category:
        for type: RoadTrafficVehicleType in by_category[category]:
            type.weight = weights[category] / by_category[category].size()
            types.append(type)
    return types
