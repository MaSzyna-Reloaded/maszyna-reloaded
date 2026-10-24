class_name SelectorVehicle
extends RefCounted

## A vehicle the scenario selector lists before a scenery is loaded - read off MaSzyna's data, a .scn
## or the game directory's vehicles - as the catalogue knows it (VehicleCatalogServer)


## The VehicleData of MaSzyna's vehicle of the data path, file and skin
static func of(data_path: String, file_name: String, skin: String, vehicle_id: String) -> VehicleData:
    var vehicle: MaszynaVehicleData = MaszynaVehicleData.new()
    vehicle.data_path = data_path
    vehicle.file_name = file_name
    vehicle.skin = skin
    vehicle.vehicle_id = vehicle_id
    return vehicle
