package ccc.compute.server.util;

import js.npm.RedisClient;

import promhx.Promise;
import promhx.deferred.DeferredPromise;

/**
 * Main path to connect to a redis instance.
 * Attempts several methods of getting the redis
 * address.
 */
class ConnectionToolsRedis
{
	inline public static var REDIS_PORT = 6379;

	public static function getRedisConnectOps() :{host:String, port:Int}
	{
		var host :String = Reflect.field(Node.process.env, ENV_REDIS_HOST);
		if (host == null || host == '') {
			host = 'redis';
		}
		host = host.replace(':', '');

		var portString :String = Reflect.field(Node.process.env, ENV_REDIS_PORT);
		if (portString == null || portString == '') {
			portString = '$REDIS_PORT';
		}
		var port :Int = Std.parseInt(portString);
		return {host:host, port:port};
	}

	public static function getRedisClient() :Promise<RedisClient>
	{
		return promhx.RetryPromise.pollDecayingInterval(getRedisClientInternal, 6, 500, 'getRedisClient');
	}

	public static function getRedisClientInternal() :Promise<RedisClient>
	{
		var redisParams = getRedisConnectOps();
		var client = RedisClient.createClient(redisParams.port, redisParams.host);
		var promise = new DeferredPromise();
		client.once(RedisEvent.Connect, function() {
			Log.debug({system:'redis', event:RedisEvent.Connect, redisParams:redisParams});
			//Only resolve once connected
			if (!promise.boundPromise.isResolved()) {
				promise.resolve(client);
			} else {
				Log.error({log:'Got redis connection, but our promise is already resolved ${redisParams.host}:${redisParams.port}'});
			}
		});
		client.on(RedisEvent.Error, function(err) {
			if (!promise.boundPromise.isResolved()) {
				client.end();
				promise.boundPromise.reject(err);
			} else {
				Log.warn({error:err, system:'redis', event:RedisEvent.Error, redisParams:redisParams});
			}
		});
		client.on(RedisEvent.Reconnecting, function(msg) {
			Log.warn({system:'redis', event:RedisEvent.Reconnecting, reconnection:msg, redisParams:redisParams});
		});
		client.on(RedisEvent.End, function() {
			Log.warn({system:'redis', event:RedisEvent.End, redisParams:redisParams});
		});
		return promise.boundPromise;
	}

	static function isRedisInEtcHosts() :Bool
	{
		try {
			var stdout :String = js.node.ChildProcess.execSync('cat /etc/hosts', {stdio:['ignore','pipe','ignore']});
			var output = Std.string(stdout);
			return output.indexOf('redis') > -1;
		} catch (ignored :Dynamic) {
			return false;
		}
	}
}