@tool
class_name LevelCatalogueMetadata
extends Resource
## Semantic metadata only; dimensions/connections always come from the real definitions.
@export var entries: Array[LevelCapabilityDescription] = []
