package ccc.compute.server.execution.routes;

import t9.js.jsonrpc.Routes;

import promhx.Promise;
import ccc.compute.shared.TypedDynamicObject;
import js.npm.bluebird.Bluebird;

/**
 * This is the HTTP RPC/API contact point to the compute queue.
 */
class RpcRoutes
{
	public static var VERSION = 'v1';

	@rpc({
		alias:'log',
		doc:'Set the log level'
	})
	public function logLevel(?level :Null<Int>) :Promise<Int>
	{
#if ((nodejs && !macro) && !excludeccc)
		if (level != null) {
			level = Std.parseInt(level + '');
			Log.warn('Setting log level=$level');
			Logger.GLOBAL_LOG_LEVEL = level;
		}
		return Promise.promise(Logger.GLOBAL_LOG_LEVEL);
#else
		return Promise.promise(1);
#end
	}

	@rpc({
		alias:'status',
		doc:'Get the running status of the system: pending jobs, running jobs, worker machines'
	})
	public function status() :Promise<SystemStatus>
	{
#if ((nodejs && !macro) && !excludeccc)
		return ServerCommands.status();
#else
		return Promise.promise(null);
#end
	}

	@rpc({
		alias:'info',
		doc:'Get the running status of this worker only'
	})
	public function info() :Promise<SystemStatus>
	{
#if ((nodejs && !macro) && !excludeccc)
		return ServerCommands.status();
#else
		return Promise.promise(null);
#end
	}

	@rpc({
		alias:'serverversion',
		doc:'Get the server version info'
	})
	public function serverVersion() :Promise<ServerVersionBlob>
	{
#if ((nodejs && !macro) && !excludeccc)
		return Promise.promise(ServerCommands.version());
#else
		return Promise.promise(null);
#end
	}

	@rpc({
		alias: 'job',
		doc: 'Commands to query jobs, e.g. status, outputs.',
		args: {
			'command': {'doc':'Command to run in the docker container [remove | kill | result | status | exitcode | stats | definition | time]'},
			'jobId': {'doc': 'Job Id(s)'}
		},
		docCustom:'   With no jobId arguments, all jobs are returned.\n   commands:\n      remove\n      kill\n      result\n      status\t\torder of job status: [pending,copying_inputs,copying_image,container_running,copying_outputs,copying_logs,finalizing,finished]\n      exitcode\n      stats\n      definition\n      time'
	})
	public function doJobCommand(command :JobCLICommand, jobId :JobId) :Promise<Dynamic>
	{
#if ((nodejs && !macro) && !excludeccc)
		return JobCommands.doJobCommand(_injector, jobId, command);
#else
		return Promise.promise(null);
#end
	}

	@rpc({
		alias: 'jobs',
		doc: 'List all job ids'
	})
	public function jobs() :Promise<Array<JobId>>
	{
#if ((nodejs && !macro) && !excludeccc)
		return JobCommands.getAllJobs(_injector);
#else
		return Promise.promise(null);
#end
	}

	@rpc({
		alias:'deleteAllJobs',
		doc:'Deletes all jobs'
	})
	@:keep
	public function deleteAllJobs()
	{
#if ((nodejs && !macro) && !excludeccc)
		return JobCommands.deleteAllJobs(_injector);
#else
		return Promise.promise(true);
#end
	}

	@rpc({
		alias:'job-stats',
		doc:'Get job stats'
	})
	@:keep
	public function jobStats(jobId :JobId, ?raw :Bool = false)
	{
#if ((nodejs && !macro) && !excludeccc)
		return JobCommands.getJobStats(_injector, jobId, raw);
#else
		return Promise.promise(null);
#end
	}

	@rpc({
		alias:'jobs-pending-delete',
		doc:'Deletes all pending jobs'
	})
	@:keep
	public function deletePending()
	{
#if ((nodejs && !macro) && !excludeccc)
		return JobCommands.deletingPending(_injector);
#else
		return Promise.promise(true);
#end
	}

	@rpc({
		alias:'job-wait',
		doc:'Waits until a job has finished before returning'
	})
	public function getJobResult(jobId :JobId, ?timeout :Float = 86400000) :Promise<JobResult>
	{
#if ((nodejs && !macro) && !excludeccc)
		return JobCommands.getJobResult(_injector, jobId, timeout);
#else
		return Promise.promise(null);
#end
	}

	@rpc({
		alias:'pending',
		doc:'Get pending jobs'
	})
	public function pending() :Promise<Array<JobId>>
	{
#if ((nodejs && !macro) && !excludeccc)
		return JobCommands.pending(_injector);
#else
		return Promise.promise(null);
#end
	}

	@rpc({
		alias:'worker-remove',
		doc:'Removes a worker'
	})
	public function workerRemove(id :MachineId) :Promise<String>
	{
#if ((nodejs && !macro) && !excludeccc)
		Assert.notNull(id);
		return Promise.promise("FAILED NOT IMPLEMENTED YET");
		// return ccc.compute.server.InstancePool.workerFailed(_redis, id);
#else
		return Promise.promise(null);
#end
	}

	@rpc({
		alias:'status-workers',
		doc:'Get detailed status of all workers'
	})
	public function statusWorkers() :Promise<Dynamic>
	{
#if ((nodejs && !macro) && !excludeccc)
		// return WorkerCommands.statusWorkers(_redis);
		return Promise.promise(null);
#else
		return Promise.promise(null);
#end
	}

// 	@rpc({
// 		alias:'reset',
// 		doc:'Resets the server: kills and removes all jobs, removes local and remote data on jobs in the database.'
// 	})
// 	public function serverReset() :Promise<Bool>
// 	{
// #if ((nodejs && !macro) && !excludeccc)
// 		return ServerCommands.serverReset(_redis, _fs);
// #else
// 		return Promise.promise(null);
// #end
// 	}

	@rpc({
		alias:'remove-all-workers-and-jobs',
		doc:'Removes a worker'
	})
	public function removeAllJobsAndWorkers() :Promise<Bool>
	{
#if ((nodejs && !macro) && !excludeccc)
		Log.warn('remove-all-workers-and-jobs');
		return Promise.promise(true)
			.pipe(function(_) {
				return deleteAllJobs();
			})
			
			// .pipe(function(_) {
			// 	return _workerProvider.setMinWorkerCount(0);
			// })
			// .pipe(function(_) {
			// 	return _workerProvider.setMaxWorkerCount(0);
			// })
			.thenTrue()
			// .pipe(function(_) {
			// 	Log.warn('Removing all workers');
			// 	return _workerProvider.shutdownAllWorkers();
			// })
			;
#else
		return Promise.promise(false);
#end
	}

	@rpc({
		alias:'runturbo',
		doc:'Run docker job(s) on the compute provider. Example:\n cloudcannon run --image=elyase/staticpython --command=\'["python", "-c", "print(\'Hello World!\')"]\'',
		args:{
			'command': {'doc':'Command to run in the docker container. E.g. --command=\'["echo", "foo"]\''},
			'image': {'doc': 'Docker image name [busybox].'},
			'imagePullOptions': {'doc': 'Docker image pull options, e.g. auth credentials'},
			'inputs': {'doc': 'Object hash of inputs.'},
			'workingDir': {'doc': 'The current working directory for the process in the docker container.'},
			'cpus': {'doc': 'Minimum number of CPUs required for this process.'},
			'maxDuration': {'doc': 'Maximum time (in seconds) this job will be allowed to run before being terminated.'},
			'meta': {'doc': 'Metadata logged and saved with the job description and results.json'}
		}
	})
	public function submitTurboJob(
		?image :String,
#if ((nodejs && !macro) && !excludeccc)
		?imagePullOptions :PullImageOptions,
#else
		?imagePullOptions :Dynamic,
#end
		?command :Array<String>,
		?inputs :Dynamic<String>,
		?workingDir :String,
		?cpus :Int = 1,
		?maxDuration :Int = 600,
		?inputsPath :String,
		?outputsPath :String,
		?meta :Dynamic
		) :Promise<JobResultsTurbo>
	{
		var request :BatchProcessRequestTurbo = {
			image: image,
			imagePullOptions: imagePullOptions,
			command: command,
			inputs: inputs,
			workingDir: workingDir,
			parameters: {cpus: cpus, maxDuration:maxDuration},
			inputsPath: inputsPath,
			outputsPath: outputsPath,
			meta: meta
		}

#if ((nodejs && !macro) && !excludeccc)
		return ServiceBatchComputeTools.runTurboJobRequest(_injector, request);
#else
		return Promise.promise(null);
#end
	}

	@rpc({
		alias:'runturbojson',
		doc:'Run docker job(s) on the compute provider. Example:\n cloudcannon run --image=elyase/staticpython --command=\'["python", "-c", "print(\'Hello World!\')"]\'',
		args:{
			'job': {'doc':'BatchProcessRequestTurbo'}
		}
	})
	public function submitTurboJobJson(job :BatchProcessRequestTurbo) :Promise<JobResultsTurbo>
	{
#if ((nodejs && !macro) && !excludeccc)
		return ServiceBatchComputeTools.runTurboJobRequest(_injector, job);
#else
		return Promise.promise(null);
#end
	}

	@rpc({
		alias:'submitjob',
		doc:'Run docker job(s) on the compute provider. Example:\n cloudcannon run --image=elyase/staticpython --command=\'["python", "-c", "print(\'Hello World!\')"]\'',
		args:{
			'command': {'doc':'Command to run in the docker container. E.g. --command=\'["echo", "foo"]\''},
			'image': {'doc': 'Docker image name [busybox].'},
			'pull_options': {'doc': 'Docker image pull options, e.g. auth credentials'},
			'inputs': {'doc': 'Array of input source objects {type:[url|inline(default)], name:<filename>, value:<string>, encoding:[utf8(default)|base64|ascii|hex]} See https://nodejs.org/api/buffer.html for more info about supported encodings.'},
			'workingDir': {'doc': 'The current working directory for the process in the docker container.'},
			'cpus': {'doc': 'Minimum number of CPUs required for this process.'},
			'maxDuration': {'doc': 'Maximum time (in seconds) this job will be allowed to run before being terminated.'},
			'resultsPath': {'doc': 'Custom path on the storage service for the generated job.json, stdout, and stderr files.'},
			'inputsPath': {'doc': 'Custom path on the storage service for the inputs files.'},
			'outputsPath': {'doc': 'Custom path on the storage service for the outputs files.'},
			'wait': {'doc': 'Do not return request until compute job is finished. Only use for short jobs.'},
			'meta': {'doc': 'Metadata logged and saved with the job description and results.json'}
		}
	})
	public function submitJob(
		?image :String,
#if ((nodejs && !macro) && !excludeccc)
		?pull_options :PullImageOptions,
#else
		?pull_options :Dynamic,
#end
		?command :Array<String>,
		?inputs :Array<ComputeInputSource>,
		?workingDir :String,
		?cpus :Int = 1,
		?maxDuration :Int = 600,
		?resultsPath :String,
		?inputsPath :String,
		?outputsPath :String,
		?containerInputsMountPath :String,
		?containerOutputsMountPath :String,
		?wait :Bool = false,
		?meta :Dynamic
		) :Promise<JobResult>
	{
		var request :BasicBatchProcessRequest = {
			image: image,
			pull_options: pull_options,
			cmd: command,
			inputs: inputs,
			workingDir: workingDir,
			parameters: {cpus: cpus, maxDuration:maxDuration},
			resultsPath: resultsPath,
			inputsPath: inputsPath,
			outputsPath: outputsPath,
			containerInputsMountPath: containerInputsMountPath,
			containerOutputsMountPath: containerOutputsMountPath,
			wait: wait,
			meta: meta
		}

#if ((nodejs && !macro) && !excludeccc)
		return ServiceBatchComputeTools.runComputeJobRequest(_injector, request);
#else
		return Promise.promise(null);
#end
	}

	@rpc({
		alias:'submitJobJson',
		doc:'Submit a job as a JSON object',
		args:{
			'job': {'doc':'BasicBatchProcessRequest'}
		}
	})
	public function submitJobJson(job :BasicBatchProcessRequest) :Promise<JobResult>
	{
#if ((nodejs && !macro) && !excludeccc)
		return ServiceBatchComputeTools.runComputeJobRequest(_injector, job);
#else
		return Promise.promise(null);
#end
	}

#if ((nodejs && !macro) && !excludeccc)
	@inject public var _injector :minject.Injector;
	@inject public var _context :t9.remoting.jsonrpc.Context;

	public function new() {}

	@post
	public function postInject()
	{
		_context.registerService(this);
	}

	public function multiFormJobSubmissionRouter() :js.node.http.IncomingMessage->js.node.http.ServerResponse->(?Dynamic->Void)->Void
	{
		return function(req, res, next) {
			var contentType :String = req.headers['content-type'];
			var isMultiPart = contentType != null && contentType.indexOf('multipart/form-data') > -1;
			if (isMultiPart) {
				ServiceBatchComputeTools.handleMultiformBatchComputeRequest(_injector, req, res, next);
			} else {
				next();
			}
		}
	}

	function returnHelp() :String
	{
		return 'help';
	}

	public function dispose() {}

	public static function router(injector :Injector) :js.node.express.Router
	{
		//Ensure there is only a single jsonrpc Context object
		//Ensure there is only a single jsonrpc Context object
		if (!injector.hasMapping(t9.remoting.jsonrpc.Context)) {
			injector.map(t9.remoting.jsonrpc.Context).toValue(new t9.remoting.jsonrpc.Context());
		}
		var context :t9.remoting.jsonrpc.Context = injector.getValue(t9.remoting.jsonrpc.Context);

		//Create all the services, and map the RPC methods to the context object
		if (!injector.hasMapping(RpcRoutes)) {
			var serviceBatchCompute = new RpcRoutes();
			injector.map(RpcRoutes).toValue(serviceBatchCompute);
			injector.injectInto(serviceBatchCompute);
		}

		if (!injector.hasMapping(ServiceTests)) {
			var serviceTests = new ServiceTests();
			injector.map(ServiceTests).toValue(serviceTests);
			injector.injectInto(serviceTests);
		}

		var router = js.node.express.Express.GetRouter();
		/* /rpc */
		//Handle the special multi-part requests. These are a special case.
		router.post(SERVER_API_RPC_URL_FRAGMENT, injector.getValue(RpcRoutes).multiFormJobSubmissionRouter());

		var timeout = 1000*60*30;//30m
		router.post(SERVER_API_RPC_URL_FRAGMENT, Routes.generatePostRequestHandler(context, timeout));
		router.get(SERVER_API_RPC_URL_FRAGMENT + '*', Routes.generateGetRequestHandler(context, SERVER_API_RPC_URL_FRAGMENT, timeout));

		return router;
	}

	public static function routerVersioned(injector :Injector) :js.node.express.Router
	{
		//Ensure there is only a single jsonrpc Context object
		if (!injector.hasMapping(t9.remoting.jsonrpc.Context)) {
			injector.map(t9.remoting.jsonrpc.Context).toValue(new t9.remoting.jsonrpc.Context());
		}
		var context :t9.remoting.jsonrpc.Context = injector.getValue(t9.remoting.jsonrpc.Context);

		//Create all the services, and map the RPC methods to the context object
		if (!injector.hasMapping(RpcRoutes)) {
			var serviceBatchCompute = new RpcRoutes();
			injector.map(RpcRoutes).toValue(serviceBatchCompute);
			injector.injectInto(serviceBatchCompute);
		}

		if (!injector.hasMapping(ServiceTests)) {
			var serviceTests = new ServiceTests();
			injector.map(ServiceTests).toValue(serviceTests);
			injector.injectInto(serviceTests);
		}

		var router = js.node.express.Express.GetRouter();
		/* /rpc */
		//Handle the special multi-part requests. These are a special case.
		router.post(VERSION, injector.getValue(RpcRoutes).multiFormJobSubmissionRouter());

		var timeout = 1000*60*30;//30m
		router.post(VERSION, Routes.generatePostRequestHandler(context, timeout));
		router.get('$VERSION*', Routes.generateGetRequestHandler(context, null, timeout));

		return router;
	}
#end
}