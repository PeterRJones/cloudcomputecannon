package ccc.storage;

typedef StorageDefinition = {
	var type: StorageSourceType;
	@:optional var rootPath: String;
	@:optional var container :String;
	@:optional var credentials :Dynamic;
	@:optional var httpAccessUrl :String;
	@:optional var extraS3SyncParameters :Array<Array<String>>;
}