chai = require 'chai'
sinon = require 'sinon'
sinonChai = require 'sinon-chai'
chaiAsPromised = require 'chai-as-promised'
chai.use(sinonChai);
chai.use(chaiAsPromised);
expect = chai.expect


request = require 'supertest'

{EventEmitter} = require 'events'
{Brain, Robot} = require 'hubot'

# Stubs
statStub =
    isFile: sinon.stub()

fsStub =
    readFileSync: sinon.stub()
    statSync: sinon.stub().returns(statStub)

httpStub =
    createServer: sinon.stub().returnsThis()
    listen: sinon.stub()

httpsStub =
    createServer: sinon.stub().returnsThis()
    listen: sinon.stub()

requestStub =
    post: sinon.stub()
    get: sinon.stub()
    defaults: sinon.stub().returnsThis()

appStub =
    use: sinon.stub()
    post: sinon.stub()

expressStub = sinon.stub().returns(appStub)

# Proxyquire will not call the original dependencies
proxyquire = require('proxyquire').noCallThru();
{Circuit} = proxyquire('../src/circuit', {
    'fs': fsStub,
    'http': httpStub,
    'https': httpsStub,
    'request': requestStub,
    'express': expressStub
});

@circuitBot = null;
robotStub = null

beforeEach ->

    robotStub =
        logger:
            info: sinon.stub()
            debug: sinon.stub()
            error: sinon.stub()
        receive: sinon.stub()
        emit: sinon.stub()
        router:
          post: sinon.stub()

describe 'Circuit adapter', ->

    describe 'expect to initialize the robot', ->

        beforeEach ->
            process.env.HUBOT_CIRCUIT_CLIENT_ID = 'client-id'
            process.env.HUBOT_CIRCUIT_CLIENT_SECRET = 'client-secret'
            process.env.HUBOT_CIRCUIT_WEBHOOKS_URL = 'https://my-app.com'

        afterEach ->
            process.env.HUBOT_CIRCUIT_CLIENT_ID = null
            process.env.HUBOT_CIRCUIT_CLIENT_SECRET = null
            process.env.HUBOT_CIRCUIT_WEBHOOKS_URL = null
            process.env.HUBOT_CIRCUIT_REST_API_URL = null
            process.env.HUBOT_CIRCUIT_SCOPE = null
            process.env.HUBOT_CIRCUIT_ADDRESS = null
            process.env.HUBOT_CIRCUIT_PORT = null

        it 'without having set the optional evnironment variables', ->
            @circuitBot = new Circuit robotStub

            conf =
                clientId: 'client-id'
                clientSecret: 'client-secret'
                hubotWebhooksUrl: 'https://my-app.com'
                circuitDomain: 'https://eu.yourcircuit.com/rest'
                scope: 'ALL'
                hubotHost: '0.0.0.0'
                hubotPort: undefined

            # Expectations
            expect(@circuitBot.conf).to.be.eql(conf)

        it 'by setting the optional evnironment variables', ->

            # Mock data
            process.env.HUBOT_CIRCUIT_REST_API_URL = 'http://another.circuit.com'
            process.env.HUBOT_CIRCUIT_SCOPE = 'ALL'
            process.env.HUBOT_CIRCUIT_ADDRESS = 'localhost'
            process.env.HUBOT_CIRCUIT_PORT = '3000'


            @circuitBot = new Circuit robotStub

            conf =
                circuitDomain: 'http://another.circuit.com'
                clientId: 'client-id'
                clientSecret: 'client-secret'
                hubotWebhooksUrl: 'https://my-app.com'
                scope: 'ALL'
                hubotHost: 'localhost'
                hubotPort: '3000'

            # Expectations
            expect(@circuitBot.conf).to.be.eql(conf)

    it 'expect to send messages', ->

        envelope =  {room: 'convId', message: parentId: 'parentId'}
        @circuitBot = new Circuit robotStub
        postMessageStub = sinon.stub(@circuitBot, 'postMessage')

        # Actual call
        @circuitBot.send envelope, 'message1', 'message2'

        # Expectations
        expect(postMessageStub).to.have.been.calledTwice
        expect(postMessageStub).to.have.been.calledWith(envelope, 'message1')
        expect(postMessageStub).to.have.been.calledWith(envelope, 'message2')

    it 'expect reply to send message', ->
        # Mock data
        envelope = 'an envelope'
        args = ['hello', 'hi']

        @circuitBot = new Circuit robotStub
        sendStub = sinon.stub(@circuitBot, 'send')

        @circuitBot.reply envelope, args

        # Expectations
        expect(sendStub).to.have.been.calledWith(envelope, args)

    describe 'retrieve a token', ->

        beforeEach ->
            process.env.HUBOT_CIRCUIT_WEBHOOKS_URL = 'http://webhook-url'
            @circuitBot = new Circuit robotStub

        afterEach ->
            requestStub.post.reset()

        it 'expect to handle error status code in retrieve token', ->

            # Mock callback response
            requestStub.post.yields(null, statusCode: 500)

            # Actual call
            retrieveToken = @circuitBot.retrieveToken()

            # Expectations
            expect(requestStub.post).to.have.been.called
            expect(retrieveToken).to.be.rejectedWith(null)

        it 'expect to handle error in retrieve token', ->

            # Mock callback response
            requestStub.post.yields('error in retrieve token', statusCode: 403)

            # Actual call
            retrieveToken = @circuitBot.retrieveToken()

            # Expectations
            expect(requestStub.post).to.have.been.called
            expect(retrieveToken).to.be.rejectedWith('error in retrieve token')

        it 'expect to successfully retrieve a token', ->

            # Mock data
            respData = '{"access_token":"abcde"}'
            options =
              auth:
                user: @circuitBot.conf.clientId
                pass: @circuitBot.conf.clientSecret
              uri: '/oauth/token'
              form:
                grant_type: 'client_credentials'
                client_id: @circuitBot.conf.clientId
                client_secret: @circuitBot.conf.clientSecret
                scope: @circuitBot.conf.scope
            # Mock callback response
            requestStub.post.yields(null, { statusCode: 200 }, respData)

            # Actual call
            retrieveToken = @circuitBot.retrieveToken()

            # Expectations
            expect(requestStub.post).to.have.been.calledWithMatch(options)
            expect(retrieveToken).to.be.fulfilled
            expect(@circuitBot.robot.token).to.be.equal('abcde')

    describe 'registers webhook', ->

        it 'expect to add webhook when an empty list retrieved', ->

            # Mock callback response
            @circuitBot = new Circuit robotStub
            getWebhookStub = sinon.stub(@circuitBot, 'getWebhook').resolves()
            addWebhookStub = sinon.stub(@circuitBot, 'addWebhook').resolves()

            # Actual call
            @circuitBot.registerWebhook().then () ->
                # Expectations
                expect(addWebhookStub).to.have.been.called
                expect(getWebhookStub).to.have.been.called

        it 'expect to register a webhook when the webhook list entries do not match with the provided', ->

            # Mock data
            respData = '[{"id": "id1", "url": "http://differentUrl.com", "filter": ["USER.USER_PRESENCE_CHANGE"], "type": "MANUAL", "subscriptionIds": ["user1"]}]'
            # Mock callback response
            @circuitBot = new Circuit robotStub
            getWebhookStub = sinon.stub(@circuitBot, 'getWebhook').resolves(JSON.parse(respData))
            addWebhookStub = sinon.stub(@circuitBot, 'addWebhook').resolves()

            # Actual call
            @circuitBot.registerWebhook().then () ->
                # Expectations
                expect(getWebhookStub).to.have.been.called
                expect(addWebhookStub).to.have.been.called

        it 'expect not to register a webhook if the webhook exists', ->
            # Mock data
            respData = '[{"id": "id2", "url": "http://test.com/hubot", "filter": ["USER.USER_PRESENCE_CHANGE"], "type": "MANUAL", "subscriptionIds": ["user1"]}]'

            # Mock callback response
            @circuitBot = new Circuit robotStub
            @circuitBot.conf =
                hubotWebhooksUrl: 'http://test.com'
            getWebhookStub = sinon.stub(@circuitBot, 'getWebhook').resolves(JSON.parse(respData))
            addWebhookStub = sinon.stub(@circuitBot, 'addWebhook')

            # Actual call
            @circuitBot.registerWebhook().then () ->
                # Expectations
                expect(getWebhookStub).to.have.been.called
                expect(addWebhookStub).to.not.have.been.called

    describe 'retrieve bot\'s profile', ->

        emitStub = null
        callback = null

        beforeEach ->
            callback = sinon.stub()
            @circuitBot = new Circuit robotStub

        afterEach ->
            requestStub.post.reset()
            requestStub.get.reset()
            callback.reset()

        it 'expect to handle error in retrieve profile', ->

            # Mock callback response
            requestStub.get.yields('error in retrieve profile', statusCode: 400)

            # Actual call
            getProfile = @circuitBot.getProfile()

            # Expectations
            expect(requestStub.get).to.have.been.called
            expect(getProfile).to.be.rejectedWith('error in retrieve profile', statusCode: 403)

        it 'expect to handle error status code in retrieve profile', ->

            # Mock callback response
            requestStub.get.yields(null, statusCode: 500)

            # Actual call
            getProfile = @circuitBot.getProfile()

            # Expectations
            expect(requestStub.get).to.have.been.called
            expect(getProfile).to.be.rejectedWith(null)

        it 'expect to successfully retrieve profile', ->

            # Mock data
            profileData = '{"displayName":"BB Bot", "userId": "123"}'
            options =
              uri: '/users/profile'

            # Mock callback response
            requestStub.get.yields(null, statusCode: 200, profileData)
            # Actual call
            getProfile = @circuitBot.getProfile()

            # Expectations
            expect(requestStub.get).to.have.been.calledWithMatch(options)
            expect(getProfile).to.be.fulfilled

    describe 'posts in conversation', ->

        parseStub = null;

        beforeEach ->
            @circuitBot = new Circuit robotStub
            parseStub = sinon.stub(JSON, 'parse')

        afterEach ->
            parseStub.restore()
            requestStub.post.reset()

        it 'expect to reject post message without providing a conversation id', ->

            # Mock data
            respData = '{"convId":"123456","type":"TEXT","text":"test post"}'

            # Actual call
            @circuitBot.postMessage()

            # Expectations
            expect(requestStub.post).to.not.have.been.called

        it 'expect to successfully post item to a conversation without a parentId', ->

            # Mock data
            respData = '{"convId":"convId","type":"TEXT","text":"test post"}'
            convId = 'convId'
            content = 'test post'
            subject = 'New subject'
            body = JSON.stringify content: content, subject: subject
            options =
                uri: '/conversations/convId/messages'
                body: body

            # Mock callback response
            requestStub.post.yields(null, { statusCode: 200 }, respData)

            # Actual call
            @circuitBot.postMessage({room: convId, subject: subject, message: parentId: null}, content)

            # Expectations
            expect(requestStub.post).to.have.been.calledWithMatch(options)
            expect(parseStub).to.have.been.calledWith(respData)

        it 'expect to successfully post item to a conversation with a parentId', ->

            # Mock data
            respData = '{"convId":"convId","type":"TEXT","text":"test post"}'
            convId = 'convId'
            content = 'test post'
            parentId = 'parentId'
            subject = 'New subject'
            body = JSON.stringify content: content, subject: subject
            options =
                uri: '/conversations/convId/messages/parentId'
                body: body

            # Mock callback response
            requestStub.post.yields(null, { statusCode: 200 }, respData)

            # Actual call
            @circuitBot.postMessage({room: convId, subject: subject, message: parentId: parentId}, content)

            # Expectations
            expect(requestStub.post).to.have.been.calledWithMatch(options)
            expect(parseStub).to.have.been.calledWith(respData)

        it 'expect to handle error status codes when posting item to a conversation', ->

            # Mock data
            respData = '{"convId":"123456","type":"TEXT","text":"test post"}'
            convId = 'convId'
            content = 'test post'

            # Mock callback response
            requestStub.post.yields(null, { statusCode: 501 }, respData)

            # Actual call
            @circuitBot.postMessage({room: convId}, content)

            # Expectations
            expect(requestStub.post).to.have.been.called
            expect(parseStub).to.not.have.been.called

        it 'expect to handle error in post item request', ->

            # Mock callback response
            requestStub.post.yields('Bad request', statusCode: 400)
            convId = 'convId'
            content = 'test post'

            # Actual call
            @circuitBot.postMessage({room: convId}, content)

            # Expectations
            expect(requestStub.post).to.have.been.called
            expect(parseStub).to.not.have.been.called

    describe 'gets webhooks', ->
        parseStub = null;

        beforeEach ->
            @circuitBot = new Circuit robotStub
            parseStub = sinon.stub(JSON, 'parse')

        afterEach ->
            parseStub.restore()

        it 'expect to retrieve webhooks', ->

            # Mock data
            respData = '[{"id": "id1", "url": "http://test.com/hubot", "filter": ["USER.USER_PRESENCE_CHANGE"], "type": "MANUAL", "subscriptionIds": ["user1"]}]'
            # Mock callback response
            requestStub.get.yields null, { statusCode: 200 }, respData

            # Actual call
            getWebhook = @circuitBot.getWebhook()

            # Expectations
            expect(requestStub.get).to.have.been.called
            expect(getWebhook).to.become(JSON.parse(respData))

        it 'expect to handle error in get webhooks request', ->

            # Mock callback response
            requestStub.get.yields('Bad request', statusCode: 400)

            # Actual call
            getWebhook = @circuitBot.getWebhook()

            # Expectations
            expect(parseStub).to.not.have.been.called
            expect(getWebhook).to.be.rejectedWith('Bad request')

        it 'expect to handle error statusCode in get webhook request', ->

            # Mock callback response
            requestStub.get.yields(null, { statusCode: 501 })

            # Actual call
            getWebhook = @circuitBot.getWebhook()

            # Expectations
            expect(parseStub).to.not.have.been.called
            expect(getWebhook).to.be.rejectedWith(null)

    describe 'adds webhooks', ->

        beforeEach ->
            @circuitBot = new Circuit robotStub
            @circuitBot.conf =
                hubotWebhooksUrl: 'http://test.com'

        it 'expect to add webhook', ->

            # Mock data
            respData = '[{"id": "id1", "url": "http://test.com/hubot", "filter": ["USER.USER_PRESENCE_CHANGE"], "type": "MANUAL", "subscriptionIds": ["user1"]}]'
            # Mock callback response
            requestStub.post.yields null, { statusCode: 200 }, respData

            # Actual call
            addWebhook = @circuitBot.addWebhook()

            # Expectations
            expect(requestStub.post).to.have.been.called
            expect(addWebhook).to.be.fulfilled

        it 'expect to handle error in add webhook request', ->

            # Mock callback response
            requestStub.post.yields('Bad request', statusCode: 400)

            # Actual call
            addWebhook = @circuitBot.addWebhook()

            # Expectations
            expect(requestStub.post).to.have.been.called
            expect(addWebhook).to.be.rejectedWith('Bad request')

        it 'expect to handle error statusCode in add webhook request', ->

            # Mock callback response
            requestStub.post.yields(null, { statusCode: 501 })

            # Actual call
            addWebhook = @circuitBot.addWebhook()

            # Expectations
            expect(requestStub.post).to.have.been.called
            expect(addWebhook).to.be.rejectedWith(null)

    describe 'runs', ->

        processExitStub = null;

        it 'expect to stop robot\'s initialization due to missing params', ->

            processExitStub = sinon.stub(process, 'exit')
            process.env.HUBOT_CIRCUIT_WEBHOOKS_URL = ''

            @circuitBot = new Circuit robotStub

            # Actual call
            @circuitBot.run()

            # Expectations
            expect(processExitStub).to.have.been.called
            processExitStub.reset()

        it 'expect to reject if an error occurs and emit error event', ->

            # processExitStub = sinon.stub(process, 'exit')
            @circuitBot = new Circuit robotStub

            @circuitBot.conf =
                clientId: 'client-id'
                clientSecret: 'client-secret'
                hubotWebhooksUrl: 'https://my-app.com'
            profileData =
                displayName: 'BB Bot'
                userId: '123'

            setupExpressStub = sinon.stub(@circuitBot, 'setupExpress')
            retrieveTokenStub = sinon.stub(@circuitBot, 'retrieveToken').resolves()
            registerWebhookStub = sinon.stub(@circuitBot, 'registerWebhook').rejects('Error')
            getProfileStub = sinon.stub(@circuitBot, 'getProfile')
            emitStub = sinon.stub(@circuitBot, 'emit')

            # Actual call
            @circuitBot.run()
            .catch () =>
                # Expectations
                expect(setupExpressStub).to.have.been.called
                expect(retrieveTokenStub).to.have.been.called
                expect(@circuitBot.robot.emit).to.have.been.called
                expect(getProfileStub).to.not.have.been.called
                expect(emitStub).to.not.have.been.called
                expect(registerWebhookStub).to.not.have.been.called


        it 'expect to emit connected event', ->

            @circuitBot = new Circuit robotStub

            @circuitBot.conf =
                clientId: 'client-id'
                clientSecret: 'client-secret'
                hubotWebhooksUrl: 'https://my-app.com'
            profileData =
                displayName: 'BB Bot'
                userId: '123'

            setupExpressStub = sinon.stub(@circuitBot, 'setupExpress')
            retrieveTokenStub = sinon.stub(@circuitBot, 'retrieveToken').resolves()
            registerWebhookStub = sinon.stub(@circuitBot, 'registerWebhook').resolves()
            getProfileStub = sinon.stub(@circuitBot, 'getProfile').resolves(profileData)
            emitStub = sinon.stub(@circuitBot, 'emit')

            # Actual call
            @circuitBot.run().then () =>

                # Expectations
                expect(setupExpressStub).to.have.been.called
                expect(retrieveTokenStub).to.have.been.called
                expect(registerWebhookStub).to.have.been.called
                expect(getProfileStub).to.have.been.called
                expect(@circuitBot.robot.name).to.be.equal('BB Bot')
                expect(@circuitBot.robot.userId).to.be.equal('123')
                expect(emitStub).to.have.been.calledWith('connected')

    describe 'setupExpress', ->

        it 'expect to register route and start an http server', ->
            fsStub.statSync.throws new Error

            # Mock data
            respData = '{"id":"1", "url": "http://locahost:8080/hubot"}'
            options =
              uri: '/webhooks'
              body: JSON.stringify
                url: process.env.HUBOT_CIRCUIT_WEBHOOKS_URL + '/hubot'
                filter: 'CONVERSATION.ADD_ITEM,CONVERSATION.UPDATE_ITEM'

            # Mock callback response
            requestStub.post.onCall(1).yields(null, statusCode: 201, respData)

            # Actual call
            @circuitBot = new Circuit robotStub
            @circuitBot.setupExpress()

            # Expectations
            expect(@circuitBot.app.use).to.have.been.called
            expect(@circuitBot.app.post).to.have.been.calledWith '/hubot'
            expect(httpStub.createServer).to.have.been.calledWith @circuitBot.app
            expect(httpStub.listen).to.have.been.calledWith @circuitBot.conf.hubotPort

        it 'expect to setup express and start an https server', ->

            fsStub.statSync.withArgs('key.pem').returns {isFile: sinon.stub().returns true}
            fsStub.statSync.withArgs('cert.pem').returns {isFile: sinon.stub().returns true}

            fsStub.readFileSync.withArgs('key.pem').returns '/some/path/key.pem'
            fsStub.readFileSync.withArgs('cert.pem').returns '/some/path/cert.pem'

            # Mock data
            respData = '{"id":"1", "url": "http://locahost:8080/hubot"}'
            options =
              uri: '/webhooks'
              body: JSON.stringify
                url: process.env.HUBOT_CIRCUIT_WEBHOOKS_URL + '/hubot'
                filter: 'CONVERSATION.ADD_ITEM,CONVERSATION.UPDATE_ITEM'

            serverOptions =
                key: '/some/path/key.pem'
                cert: '/some/path/cert.pem'
            # Mock callback response
            requestStub.post.onCall(1).yields(null, statusCode: 201, respData)

            # Actual call
            @circuitBot = new Circuit robotStub
            @circuitBot.conf =
                hubotPort: 443
                hubotHost: '0.0.0.0'

            @circuitBot.setupExpress()

            # Expectations
            expect(@circuitBot.app.use).to.have.been.called
            expect(@circuitBot.app.post).to.have.been.calledWith '/hubot'
            expect(httpsStub.createServer).to.have.been.calledWith serverOptions, @circuitBot.app
            expect(httpsStub.listen).to.have.been.calledWith @circuitBot.conf.hubotPort, @circuitBot.conf.hubotHost

    describe 'receive event from webhooks', ->

        beforeEach ->

            # Proxyquire will call through the dependencies that are not mocked
            proxyquire.callThru();
            statStub =
                isFile: sinon.stub()

            fsStub =
                readFileSync: sinon.stub()
                statSync: sinon.stub().returns(statStub)

            {Circuit} = proxyquire('../src/circuit', {
                'fs': fsStub,
                'request': requestStub
            });

            fsStub.statSync.throws new Error

            @circuitBot = new Circuit robotStub
            @circuitBot.robot.userId = 'botId'
            @circuitBot.conf =
                hubotPort: '8181'
                hubotHost: '0.0.0.0'

        afterEach (done) ->
            requestStub.post.reset()
            requestStub.get.reset()
            @circuitBot.server.close(done)

        it 'expect to send 400 when data are not provided', ->

            # Actual call
            @circuitBot.setupExpress()

            request(@circuitBot.app)
                .post('/hubot')
                .expect(400)

        it 'expect to send 400 if the event is not supported', ->

            webhook =
                type: 'participantAdded'
                item:
                    creatorId: 'participantId'
                    text:
                        parentId: 'parent-id'


            # Actual call
            @circuitBot.setupExpress()

            request(@circuitBot.app)
                .post('/hubot')
                .send(webhook)
                .expect(400)

        it 'expect to send 403 if the event received was sent by the bot', ->


            webhook =
                type: 'itemAdded'
                item:
                    creatorId: 'botId'
                    text:
                        content: 'the message'
                        parentId: 'parent-id'


            # Actual call
            @circuitBot.setupExpress()

            request(@circuitBot.app)
                .post('/hubot')
                .send(webhook)
                .expect(403)

        it 'expect to send 400 if the event does not contain any contet', ->

            webhook =
                type: 'itemAdded'
                item:
                    creatorId: 'participantId'
                    text:
                        parentId: 'parent-id'


            # Actual call
            @circuitBot.setupExpress()

            request(@circuitBot.app)
                .post('/hubot')
                .send(webhook)
                .expect(400)

        it 'expect to send 200 and handle a message that contains rich text', ->

            webhook =
                type: 'itemAdded'
                item:
                    convId: 'convId'
                    creatorId: 'participantId'
                    text:
                        content: '<span class="mention" abbr="73534d22-5687-4205-8f2d-e6aaf5d262f8">@BB Bot</span> the message'
                        parentId: 'parentId'

             message =
                user:
                    id: 'participantId'
                    name: 'participantId'
                    room: 'convId'
                text: 'BB Bot, the message'
                id: undefined
                done: false
                room: 'convId'
                parentId: 'parentId'

            # Actual call
            @circuitBot.setupExpress()

            request(@circuitBot.app)
                .post('/hubot')
                .send(webhook)
                .expect(200)
                .expect (res) =>
                    expect(@circuitBot.robot.receive).to.have.been.calledWith message

        it 'expect to send 200 and the dispatced msg contains a parentId', ->

            webhook =
                type: 'itemAdded'
                item:
                    convId: 'convId'
                    creatorId: 'participantId'
                    text:
                        content: 'the message'
                    itemId: 'parentId'

             message =
                user:
                    id: 'participantId'
                    name: 'participantId'
                    room: 'convId'
                text: 'the message'
                id: undefined
                done: false
                room: 'convId'
                parentId: 'parentId'

            # Actual call
            @circuitBot.setupExpress()

            request(@circuitBot.app)
                .post('/hubot')
                .send(webhook)
                .expect(200)
                .expect (res) =>
                    expect(@circuitBot.robot.receive).to.have.been.calledWith message

        it 'expect to send 200 and dispatch the message', ->

            webhook =
                type: 'itemAdded'
                item:
                    convId: 'convId'
                    creatorId: 'participantId'
                    text:
                        content: 'the message'
                        parentId: 'parentId'

            message =
                user:
                    id: 'participantId'
                    name: 'participantId'
                    room: 'convId'
                text: 'the message'
                id: undefined
                done: false
                room: 'convId'
                parentId: 'parentId'

            # Actual call
            @circuitBot.setupExpress()

            request(@circuitBot.app)
                .post('/hubot')
                .send(webhook)
                .expect(200)
                .expect (res) =>
                  expect(@circuitBot.robot.receive).to.have.been.calledWith(message)
