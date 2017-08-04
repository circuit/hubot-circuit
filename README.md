# hubot-circuit
==================================

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![CircleCI](https://circleci.com/gh/circuit/hubot-circuit.svg?style=shield)](https://circleci.com/gh/circuit/hubot-circuit)
[![Coverage Status](https://coveralls.io/repos/github/circuit/hubot-circuit/badge.svg)](https://coveralls.io/github/circuit/hubot-circuit)
[![Dependency Status](https://gemnasium.com/badges/github.com/circuit/hubot-circuit.svg)](https://gemnasium.com/github.com/circuit/hubot-circuit)


## Description
This is the [Circuit](http://circuit.com) adapter for [hubot](http://hubot.github.com). Now, you can create your own bots in Circuit and have them easily configured through hubot.

#### Configuration

* Start by creating a [bot application](https://hubot.github.com/docs/#getting-started-with-hubot)
* Create a Circuit client credentials application
* Get the **client_id** and **client_secret**
* Export necessary environment variables. The Circuit adapter requires 3 environment variables:

```
export HUBOT_CIRCUIT_CLIENT_ID="YOUR_CIRCUIT_CLIENT_ID"
export HUBOT_CIRCUIT_CLIENT_SECRET="YOUR_CIRCUIT_CLIENT_SECRET"
export HUBOT_CIRCUIT_WEBHOOKS_URL="YOUR_APP_URL"
```
The following are optional:
```
export HUBOT_CIRCUIT_REST_API_URL="CIRCUIT_REST_API_URL"
export HUBOT_CIRCUIT_ADDRESS="YOUR_APP_ADDRESS"
export HUBOT_CIRCUIT_PORT="YOUR_APP_PORT"
export HUBOT_CIRCUIT_SCOPE="YOUR_APP_SCOPE"
```
If you do not specify the optional parameters above the default ones will be loaded.
```
HUBOT_CIRCUIT_ADDRESS="0.0.0.0"
HUBOT_CIRCUIT_PORT="8181"
HUBOT_CIRCUIT_REST_API_URL="https://eu.yourcircuit.com/rest"
HUBOT_CIRCUIT_SCOPE="ALL"
```

#### Run hubot
```
./bin/hubot -a circuit
```

hubot-circuit uses [Rest API](https://eu.yourcircuit.com/rest/swagger/ui/index.html) and webhooks in order to communicate with Circuit. The default events that are registered through webhooks are the CONVERSATION.ADD_ITEM and CONVERSATION.UPDATE_ITEM. In order to receive events the callback url (HUBOT_CIRCUIT_WEBHOOKS_URL) that you will use must be a secure url.

###### Certificates

When you load hubot-circuit adapter, an express https server will start up on 443 port. In order for the https server to start up place the certificate files, named 'key.pem' and 'cert.pem', in the root folder of your application.


If you have not provided any certificates an http server will start up on 8181 port.

**Note:** Hubot starts a server on the address and port you have specified with the corresponding env variables (EXPRESS_BIND_ADDRESS and EXPRESS_PORT) or 0.0.0.0 and 8080, otherwise. If you do not plan to use robot.router in your scripts, you can disable the embedded hubot express server, simply by running

```
./bin/hubot -d -a circuit
```

Otherwise, you will have two servers running on 8080 and on 8181.

#### How do I get set up?


* Install dependencies with
```
npm install
```
* Run tests
```
npm test
```

#### Contribution guidelines

* Fork the project
* Clone your fork
* Create a feature branch
* Develop your feature
* Write tests
* Make sure everything still passes by running tests
* Make sure you have followed coffeescript's syntax [coffeelint](http://www.coffeelint.org/)
* Make sure coverage is not decreased
* Push your changes
* Send a pull request for your branch
