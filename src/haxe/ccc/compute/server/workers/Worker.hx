package ccc.compute.server.workers;

import cloud.MachineMonitor;

import js.npm.RedisClient;
import js.npm.ssh2.Ssh;
import js.npm.docker.Docker;

import util.DockerTools;
import util.RedisTools;
import util.SshTools;

/**
 * Represents an virtual instance somewhere in the cloud or local.
 * The machine has docker running, and it typically CoreOS.
 * It maintains an SSH connection or docker websocket connection
 * to the machine for monitoring status.
 */
class Worker
{
	public var computeStatus (get, null) :MachineStatus;
	public var id (get, null) :MachineId;

	@inject public var _redis :RedisClient;
	@inject public var _provider :WorkerProvider;
	var _definition :WorkerDefinition;
	var _id :MachineId;
	var _computeStatus :MachineStatus;
	var _stateChangeStream :Stream<MachineStatus>;
	public var log(get, null) :AbstractLogger;
	var _log :AbstractLogger;
	var _monitor :MachineMonitor;
	var _eventStream :Stream<EventStreamItem>;

	static var ALL_WORKERS = new Map<MachineId, Worker>();

	public function new(def :WorkerDefinition)
	{
		Assert.notNull(def);
		Assert.notNull(def.id);
		_log = Logger.child({'instanceid':def.id, type:'worker'});
		Assert.that(log != null);
		Assert.that(!ALL_WORKERS.exists(def.id));
		ALL_WORKERS.set(def.id, this);
		_definition = def;
	}

	public function toString() :String
	{
		return 'WORKER[id=$id computeStatus=$computeStatus]';
	}

	@post public function postInject()
	{
		Assert.notNull(_redis.connectionOption);
		_id = _definition.id;

		var machineStateChannel = '${InstancePool.REDIS_KEY_WORKER_STATUS_CHANNEL_PREFIX}${_id}';
		_stateChangeStream = RedisTools.createStreamFromHash(_redis, machineStateChannel, InstancePool.REDIS_KEY_WORKER_STATUS, _id);
		_stateChangeStream.then(function(status) {
			if (_redis == null) {
				return;
			}
			if (status != null && status != _computeStatus) {
				_computeStatus = status;
				log.debug({'status':_computeStatus});
				switch(_computeStatus) {
					case Available,Deferred:
						if (_redis != null && _monitor == null) {
							startMonitor();
						}
					case Initializing,WaitingForRemoval,Removing,Failed,Terminated:
				}
			}
		});
	}

	function startMonitor()
	{
		log.debug("Starting worker monitor");
		_monitor = new MachineMonitor();

		//Always monitor the docker daemon
		_monitor.monitorDocker(_definition.docker, 5000);

		//Monitoring disk space only makes sense for certain providers
		var type :ServiceWorkerProviderType = _provider.id;
		switch(type) {
			case pkgcloud,vagrant:
				log.info("Setting up disk monitoring");
				_monitor.monitorDiskSpace(_definition.ssh, 0.9, 10*1000);
			default:
				log.info('NOT setting up disk monitoring because type=$type is not [${ServiceWorkerProviderType.pkgcloud} or ${ServiceWorkerProviderType.vagrant}]');
		}

		//Output monitoring logs
		_monitor.docker.then(function(status) {
			log.debug({id:_id, monitor:'docker', status:Type.enumConstructor(status)});
		});

		_monitor.disk.then(function(status) {
			log.debug({id:_id, monitor:'disk', status:Type.enumConstructor(status)});
		});

		//The action taken after a failure is detected
		_monitor.status.then(function(machineStatus) {
			switch(machineStatus) {
				case Connecting,OK:
				case CriticalFailure(failureType):
					if (_redis != null) {
						onMachineFailure(failureType);
					}
			}
		});

		_eventStream = DockerTools.createEventStream(_definition.docker);
		//It is null if using the local docker daemon
		if (_eventStream != null) {
			_eventStream = _eventStream
				.then(function(event) {
					log.debug({docker_daemon_event:event});
					return null;
				})
				.errorPipe(function(err) {
					log.warn('error on event stream err=${Json.stringify(err)}');
					return Stream.stream(null);
				});
		}
	}

	/**
	 * Lost contact with the machine, we assume it is
	 * dead, so re-queue jobs and remove this machine.
	 * @return [description]
	 */
	function onMachineFailure(?failureType :Dynamic) :Promise<Bool>
	{
		log.error({'status':_computeStatus, state:'FAILURE', 'log':'Machine failure, removing from InstancePool', reason:Json.stringify(failureType)});
		return InstancePool.workerFailed(_redis, _id);
	}

	/**
	 * Doesn't actually do anything to the underlying instance, just
	 * cleans up this object.
	 * @return [description]
	 */
	public function dispose()
	{
		Log.debug({'status':_computeStatus, 'log':'dispose'});
		if (_redis == null) {
			return Promise.promise(true);
		}
		ALL_WORKERS.remove(_id);
		_redis = null;
		_definition = null;
		_id = null;
		if (_monitor != null) {
			_monitor.dispose();
			_monitor = null;
		}
		_stateChangeStream.end();
		_stateChangeStream = null;
		log = null;
		if (_eventStream != null) {
			_eventStream.end();
			_eventStream = null;
		}
		return Promise.promise(true);
	}

	public function setDefinition(def :WorkerDefinition)
	{
		_definition = def;
		return this;
	}

	function get_log() :AbstractLogger
	{
		return _log != null ? _log : Log.log;
	}

	inline function get_id() :MachineId
	{
		return _id;
	}

	inline function get_computeStatus() :MachineStatus
	{
		return _computeStatus;
	}
}