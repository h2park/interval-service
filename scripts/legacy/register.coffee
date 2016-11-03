_ = require 'lodash'
async = require 'async'
kue = require 'kue'
mongojs = require 'mongojs'
Redis   = require 'ioredis'

queue = kue.createQueue
  redis:
    createClientFactory: =>
      new Redis process.env.REDIS_URI, dropBufferSupport: true

client = new Redis process.env.REDIS_URI, dropBufferSupport: true
client.on 'ready', =>
  client.flushall =>
    database = mongojs process.env.MONGODB_URI, ['intervals']
    datastore = database.intervals

    register = (record, callback) =>
      return process.nextTick callback unless record.data?
      console.log(record)
      return process.nextTick callback if record.data.fireOnce
      console.log record.id, record.token
      return process.nextTick callback unless record.token?
      console.log record.ownerId
      queue.create('register', record.data)
        .events(false)
        .removeOnComplete(true)
        .ttl(5000)
        .save (error) =>
          process.nextTick =>
            callback error

    datastore.find {"data.fireOnce": { "$exists": false }}, (error, records) =>
      console.log(records.length);
      async.eachSeries records, register, (error) =>
        console.log {error}
        process.exit 0
