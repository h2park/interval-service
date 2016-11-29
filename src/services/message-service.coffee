_        = require 'lodash'
async    = require 'async'
moment   = require 'moment'
uuid     = require 'uuid'
debug    = require('debug')('interval-service:message-service')
overview = require('debug')('interval-service:message-service:overview')

class MessageService
  constructor: ({database}) ->
    throw new error 'MessageService: requires database' unless database?
    @collection = database.collection 'soldiers'

  subscribe: (params={}, callback) =>
    debug 'subscribe', JSON.stringify params
    unless params.sendTo? and params.nodeId?
      return callback @_userError('nodeId or sendTo not defined', 422)
    if params.noUnsubscribe and !params.fireOnce
      return callback @_userError('noUnsubscribe should also set fireOnce', 422)
    if !params.cronString and params.intervalTime < 1000
      return callback @_userError('intervalTime must be at least 1000ms', 422)
    @_cloneJob params, callback

  unsubscribe: (params={}, callback) =>
    debug 'unsubscribe', JSON.stringify params
    unless params.sendTo? and params.nodeId?
      return callback @_userError('nodeId or sendTo not defined', 422)
    @_removeClonedJob params, callback

  _cloneJob: (data, callback) =>
    @collection.findOne @_getQuery(data), {_id: false}, (error, job) =>
      return callback error if error?
      return callback @_userError("Missing credentials", 412) unless job?
      @collection.insert @_cloneJobRecord(job, data), callback

  _updateJob: (data, callback) =>
    @collection.update @_getQuery(data), @_getUpdateQuery(data), callback

  _getQuery: ({ sendTo, nodeId }) =>
    query = {}
    query['metadata.ownerUuid'] = sendTo
    query['metadata.nodeId'] = nodeId
    query['metadata.credentialsOnly'] = true
    return query

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
    transactionId = uuid.v1() if fireOnce and !transactionId?
    job.data ?= {}
    job.data.nodeId = nodeId
    job.data.sendTo = sendTo
    job.data.transactionId = transactionId if transactionId?
    job.data.fireOnce = fireOnce || false
    job.metadata ?= {}
    job.metadata.transactionId = transactionId if transactionId?
    job.metadata.nonce = nonce if nonce?
    job.metadata.intervalTime = parseInt(intervalTime) if intervalTime?
    job.metadata.cronString = cronString if cronString?
    job.metadata.processAt = moment().unix()
    job.metadata.processNow = true
    job.metadata.fireOnce = fireOnce || false
    job.metadata.credentialsOnly = false
    return job

  _removeClonedJob: (data, callback) =>
    {
      sendTo,
      nodeId,
      transactionId,
      fireOnce
    } = data

    query = {}
    query['metadata.ownerUuid'] = sendTo
    query['metadata.transactionId'] = transactionId if transactionId?
    query['metadata.nodeId'] = nodeId
    query['metadata.credentialsOnly'] = false
    @collection.remove query, callback

  _userError: (message, code) =>
    error = new Error message
    error.code = code ? 500
    return error

module.exports = MessageService
