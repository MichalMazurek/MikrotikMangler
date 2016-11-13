_ = require('lodash')
app = angular.module("mikrotikMangler")

app.controller "IndexController", ($scope, parallaxHelper, $http, monitoringSocket, $q) ->
  $scope.random_bg = "bg" + (Math.floor(Math.random() * 6) + 1)
  $scope.background = parallaxHelper.createAnimator(-0.3, 150, -600);
  $scope.loading = yes
  $scope.subnets_loading = yes
  $scope.gateways = []
  $scope.subnets = []
  $scope.status = {}
  $scope.routing_marks = {}
  $scope.routing_values = []

  monitoringSocket.emit("/api/v1/channel/subscribe")

  monitoringSocket.on "monitoring", (message) ->
    if message.match(/^srm:/)
      [cmd, subnet, routing_mark] = message.split(/:/)
      $scope.routing_marks[subnet] = routing_mark

  $scope.get_status = (gw) -> $scope.status[gw]

  $scope.refresh_gw = (gw) ->
    $scope.status[gw] = undefined
    $http.get("/api/v1/gateway/"+gw).then (response) ->
      data = response.data
      $scope.status[data.gateway] = data.status
  $scope.status_healthy = (status) ->
    if status isnt undefined
      return status.match(/unreachable/) is null
    else
      return yes

  $http.get("/api/v1/gateway").then (response) ->
    $scope.gateways = response.data
    $scope.loading = no
    promise = undefined
    $scope.gateways.forEach (gw, i) ->
      if promise is undefined
        promise = $scope.refresh_gw(gw)
      else
        promise = promise.then () ->
          $scope.refresh_gw(gw)

  $http.get("/api/v1/global_routing_mark").then (response) ->
    $scope.global_routing_mark = response.data

  $scope.refresh_routing_mark = (subnet) ->
    $http.get("/api/v1/subnet/"+subnet.subnet.replace("/", "-")).then (response) ->
      data = response.data
      $scope.routing_marks[data.subnet] = data.routing_mark
      $scope.routing_values.push(data.routing_mark) if $scope.routing_values.indexOf(data.routing_mark) is -1

  $scope.change_routing_mark = (subnet, new_value) ->

    if subnet == 'global'
      $scope.global_routing_mark = undefined
      _.reduce(_.filter($scope.subnets, (s) -> s.global), (promise, subnet) ->
        promise.then (response) ->
          $http.post("/api/v1/subnet/"+subnet.subnet.replace("/", '-'), {'routing_mark': new_value})
      , $http.post("/api/v1/global_routing_mark", {'routing_mark': new_value}))
      .then () ->
        $scope.global_routing_mark = new_value
    else
      $scope.routing_marks[subnet] = undefined
      $http.post("/api/v1/subnet/"+subnet.replace("/", '-'), {'routing_mark': new_value})


  $http.get("/api/v1/subnet").then (response) ->
    $scope.subnets = response.data
    $scope.subnets_loading = no
  .then () ->
    $http.get("/api/v1/routing_marks").then (response) ->
      $scope.routing_values = response.data
  .then () ->
    promise = undefined
    $scope.subnets.forEach (subnet, i) ->
      if promise is undefined
        promise = $scope.refresh_routing_mark(subnet)
      else
        promise = promise.then () ->
          $scope.refresh_routing_mark(subnet)
