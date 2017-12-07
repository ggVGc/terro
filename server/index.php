<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta http-equiv="pragma" content="no-cache" />
    <title>Terro</title>
    <script src="js/lodash.js" type="text/javascript" charset="utf-8"></script>
    <script type="text/javascript" src="js/main.js"> </script>
    <style type="text/css">
      canvas { border: 1px solid black; margin: 0; padding:0 }
      body { border: 0px ; margin: 0; padding:0 }
    </style>
  </head>
  <body>
    <canvas id="canvas1" width="600" height="600"></canvas>
    <!-- <canvas id="canvas2" width="200" height="200"></canvas> -->
    <div id="messages"> </div>
    <div id="credits"></div>
    <p>
      Left click to place spawner.Right click to place defense.
      <br />
      Missiles will only target enemy spawners, but will hit defenses if they are in the way.
      <br />
      Destroy other players building to earn credits.
      <br />
      Place buildings inside yellow areas to increase continuous credit generation.
      <br />
    </p>
  </body>
</html>
