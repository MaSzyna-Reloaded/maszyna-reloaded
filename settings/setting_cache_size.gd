class_name SettingCacheSize
extends SettingOption

## The caches' maximum size: the sizes the core offers (ResourceCacheServer.max_size_get_choices()),
## in GB, and no limit. The value is the size in bytes; one no choice holds shows as the largest
## size not above it.

## The bytes of the GB a choice is named in - ResourceCacheServer's sizes are whole GiB
const BYTES_PER_GB: int = 1024 * 1024 * 1024

## The choices' sizes, by id
var _sizes: PackedInt64Array = []


func _setup() -> void:
    _sizes = ResourceCacheServer.max_size_get_choices()
    for id: int in _sizes.size():
        if _sizes[id] == ResourceCacheServer.MAX_SIZE_UNLIMITED:
            %Options.add_item("No limit", id)
        else:
            %Options.add_item("%d GB" % roundi(_sizes[id] / float(BYTES_PER_GB)), id)


func _value_of(id: int) -> Variant:
    return _sizes[id]


func _id_of(value: Variant) -> int:
    var id: int = _sizes.find(int(value))
    if id >= 0:
        return id
    id = 0
    for choice: int in _sizes.size():
        if not _sizes[choice] == ResourceCacheServer.MAX_SIZE_UNLIMITED and _sizes[choice] <= int(value):
            id = choice
    return id
