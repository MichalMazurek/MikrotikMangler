
angular = require("angular")
angularRoute = require("angular-route")
angularSocketIo = require("angular-socket-io")
angularAnimate = require("angular-animate")
angularScrolll = require("angular-scroll")
angularParallax = require("angular-parallax")
socketIO = require("socket.io-client")

app = angular.module("mikrotikMangler", ["ngRoute", "btford.socket-io", "ngAnimate", "duParallax"])

controllers = require("./controllers")

app.config ($routeProvider, $locationProvider) ->
  $routeProvider.when "/",
    controller: "IndexController",
    templateUrl: "/partials/index.html",

  $locationProvider.html5Mode yes

app.factory 'monitoringSocket', (socketFactory) ->
  socketFactory()
