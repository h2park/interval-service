_        = require 'lodash'
async    = require 'async'
moment   = require 'moment'
debug    = require('debug')('interval-service:message-service')
overview = require('debug')('interval-service:message-service:overview')

class MessageService
  constructor: ({database, @client}) ->
    throw new error 'MessageService: requires database' unless database?
    throw new error 'MessageService: requires client' unless @client?
    @collection       = database.collection 'soldiers'
    @legacyCollection = database.collection 'intervals'

  subscribe: (params={}, callback) =>
    debug 'subscribe', JSON.stringify params
    unless params.sendTo? and params.nodeId?
      return callback @_userError('nodeId or sendTo not defined', 422)
    if params.noUnsubscribe and !params.fireOnce
      return callback @_userError('noUnsubscribe should also set fireOnce', 422)
    if !params.cronString and params.intervalTime < 1000
      return callback @_userError('intervalTime must be at least 1000ms', 422)
    @_storeJobInMongo params, (error) =>
      return callback error if error?
      @_deactivateLegacy params, callback

  unsubscribe: (params={}, callback) =>
    debug 'unsubscribe', JSON.stringify params
    unless params.sendTo? and params.nodeId?
      return callback @_userError('nodeId or sendTo not defined', 422)
    @_removeJobInMongo params, callback

  _storeJobInMongo: (data, callback) =>
    fireOnce = data.fireOnce || false
    return @_cloneJob(data, callback) if fireOnce
    return @_updateJob(data, callback)

  _deactivateLegacy: ({ sendTo, nodeId, transactionId }, callback) =>
    redisNodeId = transactionId ? nodeId
    @client.del "interval/active/#{sendTo}/#{redisNodeId}", (error) =>
      return callback error if error?
      callback null
    return # redis promise fix

  _cloneJob: (data, callback) =>
    @collection.findOne @_getQuery(data), {_id: false}, (error, job) =>
      return callback error if error?
      return @_cloneFromLegacy data, callback unless job?
      @collection.insert @_cloneJobRecord(job, data), callback

  _cloneFromLegacy: (data, callback) =>
    query =
      'ownerId': data.sendTo,
      'nodeId' : data.nodeId,
    @legacyCollection.findOne query, {_id: false}, (error, legacyJob) =>
      return callback error if error?
      return callback @_userError('Missing record', 404) unless legacyJob?
      convertedJob = @_cloneLegacyJobRecord(legacyJob)
      @collection.insert @_cloneJobRecord(convertedJob, data), callback

  _updateJob: (data, callback) =>
    @collection.update @_getQuery(data), @_getUpdateQuery(data), callback

  _getQuery: ({ sendTo, nodeId }) =>
    query = {}
    query['metadata.ownerUuid'] = sendTo
    query['metadata.nodeId'] = nodeId
    return query

  _getUpdateQuery: (data) =>
    {
      sendTo,
      intervalTime,
      fireOnce,
      nodeId,
      transactionId,
      nonce,
      cronString,
    } = data
    update = {}
    update['data.nodeId'] = nodeId
    update['data.sendTo'] = sendTo
    update['data.transactionId'] = transactionId if transactionId?
    update['data.fireOnce'] = false
    update['metadata.nonce'] = nonce if nonce?
    update['metadata.intervalTime'] = parseInt(intervalTime) if intervalTime?
    update['metadata.cronString'] = cronString if cronString?
    update['metadata.processAt'] = moment().unix()
    update['metadata.processNow'] = true
    update['metadata.fireOnce'] = false
    return { $set: update }

  _cloneJobRecord: (job={}, data) =>
    job = _.cloneDeep(job)
    {
      sendTo,
      intervalTime,
      fireOnce,
      nodeId,
      transactionId,
      nonce,
      cronString,
    } = data
    job.data ?= {}
    job.data.nodeId = nodeId
    job.data.sendTo = sendTo
    job.data.transactionId = transactionId
    job.data.fireOnce = true
    job.metadata ?= {}
    delete job.metadata.nodeId
    job.metadata.transactionId = transactionId
    job.metadata.nonce = nonce if nonce?
    job.metadata.intervalTime = parseInt(intervalTime) if intervalTime?
    job.metadata.cronString = cronString if cronString?
    job.metadata.processAt = moment().unix()
    job.metadata.processNow = true
    job.metadata.fireOnce = true
    return job

  _cloneLegacyJobRecord: ({ id, token, ownerId, data }) =>
    {
      sendTo,
      intervalTime,
      fireOnce,
      nonce,
      cronString,
      nodeId,
      transactionId,
    } = data ? {}
    fireOnce ?= false
    record = {
      data: {}
      metadata: {}
    }
    record.data.nodeId = nodeId
    record.data.sendTo = sendTo ? ownerId
    record.data.transactionId = transactionId if transactionId?
    record.data.fireOnce = fireOnce
    record.data.uuid = id if id?
    record.data.token = token if token?
    record.data.nodeId = nodeId if nodeId?
    record.metadata.nonce = nonce if nonce?
    record.metadata.intervalTime = parseInt(intervalTime) if intervalTime?
    record.metadata.cronString = cronString if cronString?
    record.metadata.fireOnce = fireOnce
    record.metadata.ownerUuid = ownerId
    record.metadata.intervalUuid = id if id?
    record.metadata.nodeId = nodeId
    return record

  _removeJobInMongo: (data, callback) =>
    {
      sendTo,
      nodeId,
      transactionId,
      fireOnce
    } = data

    query = {}
    query['metadata.ownerUuid'] = sendTo
    if transactionId?
      query['metadata.transactionId'] = transactionId
      query['metadata.nodeId'] = nodeId
    else
      query['metadata.nodeId'] = nodeId
    @collection.remove query, callback

  _userError: (message, code) =>
    error = new Error message
    error.code = code ? 500
    return error

module.exports = MessageService
