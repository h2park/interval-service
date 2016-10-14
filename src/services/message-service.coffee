_       = require 'lodash'
async   = require 'async'
debug   = require('debug')('interval-service:message-service')
mongojs = require 'mongojs'
Redis   = require 'ioredis'

class MessageService
  constructor: (dependencies={}) ->
    {@mongodbUri, @redisClient, @redisUri} = dependencies
    throw new error 'IntervalService requires: mongodbUri' unless @mongodbUri?
    throw new error 'IntervalService requires: redisUri' unless @redisUri?
    throw new error 'IntervalService requires: redisClient' unless @redisClient?

    @db = mongojs @mongodbUri, ['intervals']
    @datastore = @db.intervals

    @kue = dependencies.kue ? require 'kue'
    @queue = @kue.createQueue
      jobEvents: false
      redis:
        createClientFactory: =>
          new Redis @redisUri, dropBufferSupport: true

  pong: (params, callback) =>
    debug 'pong', JSON.stringify params
    @createPongJob params, callback

  subscribe: (params, callback) =>
    debug 'subscribe', JSON.stringify params
    return callback(new Error 'nodeId or sendTo not defined') unless params?.sendTo? && params?.nodeId?
    return callback(new Error 'noUnsubscribe should also set fireOnce') if params.noUnsubscribe and !params.fireOnce
    return callback(new Error 'intervalTime must be at least 1000ms') if !params.cronString && params.intervalTime < 1000
    @createRegisterJob params, callback

  unsubscribe: (params, callback) =>
    debug 'unsubscribe', JSON.stringify params
    return callback new Error 'nodeId or sendTo not defined' unless params?.sendTo? && params?.nodeId?
    @createUnregisterJob params, callback

  createRegisterJob: (data, callback) =>
    @storeCredentialsInRedis data, (error) =>
      return callback error if error?
      @storeJobInMongo data, (error) =>
        return callback error if error?

        job = @queue.create('register', data)
          .delay(0)
          .ttl(5000)
          .priority('critical')
          .attempts(5)
          .events(false)
          .removeOnComplete(true)
          .save (error) =>
            callback error, job

  storeJobInMongo: (data, callback) =>
    ownerId = data.sendTo
    nodeId = data.transactionId ? data.nodeId # allow dynamic intervals
    return callback() if data?.fireOnce
    @datastore.update {ownerId, nodeId}, {$set: {ownerId, nodeId, data}}, upsert: true, callback

  storeCredentialsInRedis: (data, callback) =>
    flowId = data.sendTo
    ownerId = flowId
    nodeId = data.nodeId
    redisNodeId = data.transactionId ? data.nodeId
    @datastore.findOne {ownerId, nodeId}, (error, credentials) =>
      return callback error if error?
      return callback() unless credentials?
      redisData = [
        "interval/uuid/#{flowId}/#{redisNodeId}"
        credentials.id
        "interval/token/#{flowId}/#{redisNodeId}"
        credentials.token
      ]
      @redisClient.mset redisData, callback

  createPongJob: (data, callback)=>
    job = @queue.create('pong', data)
      .ttl(5000)
      .events(false)
      .removeOnComplete(true)
      .save (error) =>
        callback error, job

  createUnregisterJob: (data, callback)=>
    job = @queue.create('unregister', data)
      .ttl(5000)
      .events(false)
      .removeOnComplete(true)
      .save (error) =>
        callback error, job

module.exports = MessageService
