_ = require 'lodash'
async = require 'async'
mongojs = require 'mongojs'
Redis   = require 'ioredis'

client = new Redis process.env.REDIS_URI, dropBufferSupport: true
database = mongojs process.env.MONGODB_URI, ['intervals']
datastore = database.intervals

saveToMongo = (data, callback) =>
  return callback() unless data?
  ownerId = data.sendTo
  nodeId = data.nodeId
  console.log 'saving to mongo...'
  record = {ownerId, nodeId, data}
  datastore.update {ownerId, nodeId}, record, upsert: true, callback

fetchFromRedisAndSaveToMongo = (key, callback) =>
  fetchFromRedis key, (data) =>
    saveToMongo data, callback

fetchFromRedis = (key, callback) =>
  console.log 'fetchFromRedis', key
  client.smembers key, (error, jobIds) =>
    return callback error if error?
    client.hget "{q}:job:#{_.first(jobIds)}", "data", (error, data) =>
      return callback error if error?
      data = JSON.parse data
      callback data if data?
      client.hget "q:job:#{_.first(jobIds)}", "data", (error, data) =>
        return callback error if error?
        data = JSON.parse data
        callback data

client.keys 'interval/job*', (error, keys) =>
  throw error if error?
  async.eachSeries keys, fetchFromRedisAndSaveToMongo, (error) =>
    console.log {error}
    process.exit 0
