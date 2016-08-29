_ = require 'lodash'
async = require 'async'
mongojs = require 'mongojs'
Redis   = require 'ioredis'

client = new Redis process.env.REDIS_URI, dropBufferSupport: true
database = mongojs process.env.MONGODB_URI, ['intervals']
datastore = database.intervals

saveToMongo = (data, callback) =>
  return callback() unless data?
  {sendTo, nodeId, jobId} = data
  # console.log 'saving to mongo...'
  datastore.update {sendTo, nodeId, jobId}, data, upsert: true, callback

hgetData = (key, callback) =>
  client.hget key, "data", (error, data) =>
    return callback error if error?
    data = JSON.parse data
    callback null, data

getJob = (jobId, callback) =>
  return callback() unless jobId?
  hgetData "{q}:job:#{jobId}", (error, data) =>
    return callback error, data, jobId if error? or data?
    hgetData "q:job:#{jobId}", (error, data) =>
      return callback error, data, jobId

findAndDestroy = (key, jobData, jobId, callback) =>
  return callback null, jobData if jobData?
  newKey = key.replace /^interval\/job/, '*'
  client.keys newKey, (error, allKeys) =>
    # console.log 'eliminate!', allKeys
    keys = _.filter allKeys, (key) =>
      return !key.match /^interval\/job/
    # console.log 'clone!', keys
    client.mget keys, (error, keyData) =>
      # console.log {error}, 'keyData!', keyData
      return callback error if error?
      newData = {orphan:{}}
      for i in [0..keys.length-1]
        newData.orphan[keys[i]] = keyData[i]
      [allMatch, sendTo, nodeId] = /\/([^\/]*)\/([^\/]*)$/.exec(key)
      newData.sendTo = sendTo
      newData.nodeId = nodeId
      newData.jobId = jobId
      # console.log {newData}
      return callback null, newData, allKeys

fetchFromRedis = (key, callback) =>
  console.log 'fetchFromRedis', key
  client.smembers key, (error, jobIds) =>
    return callback error if error?
    if jobIds.length>1
      console.error key, "had multiple jobIds:", jobIds
    getJob _.last(jobIds), callback

fetchFromRedisAndSaveToMongo = (key, callback) =>
  fetchFromRedis key, (error, jobData, jobId) =>
    return callback error if error?
    return callback unless jobId?
    findAndDestroy key, jobData, jobId, (error, jobData, cleanupKeys) =>
      saveToMongo jobData, (error) =>
        return callback error if error?
        console.log key, 'no cleanup keys!' if !cleanupKeys?
        # console.log 'n cleanups:', cleanupKeys.length if cleanupKeys?
        client.del cleanupKeys, callback
        # callback()

scanner = (cursor) =>
  console.log 'scanning...', cursor
  client.scan cursor, 'MATCH', 'interval/job*', 'COUNT', '100', (error, data) =>
    console.log {error}, data[1].length
    process.exit 1 if error?
    keys = data[1]
    async.eachLimit keys, 10, fetchFromRedisAndSaveToMongo, (error) =>
      if error?
        console.log {error}
        process.exit 1
      process.exit 0 if !data? or data[0] == '0'
      scanner(data[0])

scanner(0)

# client.keys 'interval/job*', (error, keys) =>
#   throw error if error?
#   async.eachLimit keys, 10, fetchFromRedisAndSaveToMongo, (error) =>
#     console.log {error}
#     process.exit 0
