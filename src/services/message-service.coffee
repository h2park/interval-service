_        = require 'lodash'
async    = require 'async'
moment   = require 'moment'
debug    = require('debug')('interval-service:message-service')
overview = require('debug')('interval-service:message-service:overview')

class MessageService
  constructor: ({database}) ->
    throw new error 'IntervalService requires: database' unless database?
    @collection = database.collection 'soldiers'

  subscribe: (params={}, callback) =>
    debug 'subscribe', JSON.stringify params
    unless params.sendTo? and params.nodeId?
      return callback @_userError('nodeId or sendTo not defined', 422)
    if params.noUnsubscribe and !params.fireOnce
      return callback @_userError('noUnsubscribe should also set fireOnce', 422)
    if !params.cronString and params.intervalTime < 1000
      return callback @_userError('intervalTime must be at least 1000ms', 422)
    @_storeJobInMongo params, callback

  unsubscribe: (params={}, callback) =>
    debug 'unsubscribe', JSON.stringify params
    unless params.sendTo? and params.nodeId?
      return callback @_userError('nodeId or sendTo not defined', 422)
    @_removeJobInMongo params, callback

  _storeJobInMongo: (data, callback) =>
    fireOnce = data.fireOnce || false
    return @_cloneJob(data, callback) if fireOnce
    return @_updateJob(data, callback)

  _cloneJob: (data, callback) =>
    {
      sendTo,
      intervalTime,
      fireOnce,
      nodeId,
      transactionId,
      nonce,
      cronString,
    } = data
    query = {}
    query['metadata.ownerUuid'] = sendTo
    query['metadata.nodeId'] = nodeId
    @collection.findOne query, {_id: false}, (error, job) =>
      return callback error if error?
      return callback new Error('Missing record') unless job?
      job.data.nodeId = nodeId
      job.data.sendTo = sendTo
      job.data.transactionId = transactionId
      job.data.fireOnce = true
      delete job.metadata.nodeId
      job.metadata.transactionId = transactionId
      job.metadata.nonce = nonce if nonce?
      job.metadata.intervalTime = intervalTime if intervalTime?
      job.metadata.cronString = cronString if cronString?
      job.metadata.processAt = moment().unix()
      debug 'creating cloned job', job
      @collection.insert job, callback

  _updateJob: (data, callback) =>
    { sendTo, nodeId } = data
    query = {}
    query['metadata.ownerUuid'] = sendTo
    query['metadata.nodeId'] = nodeId
    update = @_getUpdateQuery(data)
    overview 'updateJob', update
    @collection.update query, {$set: update}, {upsert: true}, callback

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
    update['data.fireOnce'] = fireOnce || false
    update['metadata.nonce'] = nonce if nonce?
    update['metadata.intervalTime'] = intervalTime if intervalTime?
    update['metadata.cronString'] = cronString if cronString?
    update['metadata.processAt'] = moment().unix() unless fireOnce
    return update

  _removeJobInMongo: (data, callback) =>
    {
      sendTo,
      nodeId,
      transactionId,
    } = data

    query = {}
    query['metadata.ownerUuid'] = sendTo
    query['metadata.nodeId'] = nodeId if nodeId?
    query['metadata.transactionId'] = transactionId if transactionId?
    @collection.remove query, callback

  _userError: (message, code) =>
    error = new Error message
    error.code = code ? 500
    return error

module.exports = MessageService
