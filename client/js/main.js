
function aiController(game) {
  setInterval(function(){
    console.log("My spawners: ", game.mySpawners());
    console.log("Enemy spawners: ", game.enemySpawners());
    console.log("My bullets: ", game.myBullets());
    console.log("Enemy bullets: ", game.enemyBullets());
    console.log("Credits: ", game.credits());
    if (false) {
      // TODO: Implement a useful AI
      game.placeSpawner(100,100);
      game.placeDefense(50, 50);
    }
  }, 1000);
}


// var host = location.origin.replace(/^http/, 'ws');
var host = "ws://localhost:4000/socket";
// var host = "ws://terro.herokuapp.com/socket";


(function() {
  var lastTime = 0;
  var vendors = ['ms', 'moz', 'webkit', 'o'];
  for(var x = 0; x < vendors.length && !window.requestAnimationFrame; ++x) {
    window.requestAnimationFrame = window[vendors[x]+'RequestAnimationFrame'];
    window.cancelAnimationFrame = window[vendors[x]+'CancelAnimationFrame'] || window[vendors[x]+'CancelRequestAnimationFrame'];
  }

  if (!window.requestAnimationFrame)
    window.requestAnimationFrame = function(callback, element) {
      var currTime = new Date().getTime();
      var timeToCall = Math.max(0, 16 - (currTime - lastTime));
      var id = window.setTimeout(function() { callback(currTime + timeToCall); }, 
                                 timeToCall);
      lastTime = currTime + timeToCall;
      return id;
    };

    if (!window.cancelAnimationFrame)
      window.cancelAnimationFrame = function(id) {
        clearTimeout(id);
      };
}());


// Hack render scaling multiplier. This is just a prototype anyway. 
var rendMult = 3;

var msgArea;
var opponentsText;
var FRAME_DELTA = 100;

var SPAWNER = {};
SPAWNER.OTHER = 0;
SPAWNER.MINE = 1;
var PROJECTILE = {};
PROJECTILE.OTHER = 2;
PROJECTILE.MINE = 3;
var DEFENSE = {};
DEFENSE.OTHER = 4;
DEFENSE.MINE = 5;

var MAX_TYPES = 6;

var ThingInfos = {};
ThingInfos[SPAWNER.MINE] = {col: [0,0,200], size: 6};
ThingInfos[SPAWNER.OTHER] = {col: [200,0,0], size: 6};
ThingInfos[PROJECTILE.MINE] = {col: [0,0,255], size: 2};
ThingInfos[PROJECTILE.OTHER] = {col: [240,30,0], size: 2};
ThingInfos[DEFENSE.MINE] = {col: [20,200,50], size: 6};
ThingInfos[DEFENSE.OTHER] = {col: [160,0,160], size: 6};


var BUILD_AREA_SIZE = 29;


function setMsg(m) {
  msgArea.innerHTML = m;
}


var msgHandlers = { };

msgHandlers.opponentLeft = function (state, msg) {
  opponentsText.innerHTML = "OPPONENT HAS QUIT";
};


msgHandlers.opponents = function (state, msg) {
  opponentsText.innerHTML = "Opponents: "+msg.names;
};


msgHandlers.id = function (state, msg) {
  setMsg('Game on!');
  state.myID = msg.id;
  console.log("ID:", state.myID);
};


msgHandlers.resourceSlots = function (state, msg) {
  state.resourceSlots = _.map(msg.slots, function(s){
    return {
      pos: s
    };
  });
  console.log("resourceSlots: ", state.resourceSlots);
};


msgHandlers.credits = function (state, msg) {
  document.getElementById('credits').innerHTML = "Credits: "+Math.floor(state.credits);
  state.credits = msg.c;
};


msgHandlers.addThing = function (state, data) {
  state.worldState[data.type][data.id] = _.cloneDeep(data.obj);
};


msgHandlers.removeThing = function (state, data) {
  delete state.worldState[data.type][data.id];
};


function openChannel(nick) {
  var socket = new Phoenix.Socket(host, {});

  socket.connect({});

  socket.onOpen( function(ev){ console.log("OPEN", ev);});
  socket.onError( function(ev){console.log("ERROR", ev);});
  socket.onClose( function(e){console.log("CLOSE", e);});

  return socket.channel("rooms:game", {nick:nick});
}


function makeIdArr(things) {
  var arr = [];
  _.forOwn(things, function(v,k){
    var x = {
      id: parseInt(k, 10),
      pos: {x:v.pos[0], y:v.pos[1]},
    };
    if (v.dir) {
      x.dir = {x:v.dir[0], y:v.dir[1]};
    }
     arr.push(x);
  });
  return arr;
}

function runGame(canvas, nick){
  var state = {};
  state.worldState = _.times(MAX_TYPES, function(){return {};});
  state.credits = 0;
  var ctx;

  setMsg('connecting');

  var chan = openChannel(nick);

  _.forOwn(msgHandlers, function(handler, key){
    chan.on(key, function(msg){
      handler(state, msg);
    });
  });

  chan
    .join({nick:nick})
    .receive("ignore", function(){ console.log("auth error");})
    .receive("ok", function(){
      setMsg("waiting for other player");
      console.log("join ok");
    })
    .after(10000, function(){
      console.log("Connection interruption");
    });

  chan.onError(function(e){console.log("something went wrong on channel", e);});
  chan.onClose(function(e){console.log("channel closed", e);});

  ctx = canvas.getContext('2d');

  canvas.style.cursor = 'none';


  requestAnimationFrame(doFrame);


  function updateProjectile(delta){
    return function(p){
      p.pos[0] = p.pos[0] + p.dir[0]/FRAME_DELTA * delta;
      p.pos[1] = p.pos[1] + p.dir[1]/FRAME_DELTA * delta;
    };
  }


  function update(state, delta) {
    _.forOwn(state.worldState[PROJECTILE.MINE], updateProjectile(delta));
    _.forOwn(state.worldState[PROJECTILE.OTHER], updateProjectile(delta));
  }

  
  function handleClick(clickType, chan, x, y) {
    if (state.myID === null) {
      return;
    }
    chan.push("click", {
      value: [clickType, x/rendMult,y/rendMult]
    });
  }

  var self = {
    canvas: canvas,

    placeSpawner: function(x,y){
      handleClick(0, chan, x, y);
    },

    placeDefense: function(x,y){
      handleClick(1, chan, x, y);

    },

    drawCursorBuilding: function(x, y) {
      ctx.fillStyle = "rgba(50,50,50, 0.2)";
      // ctx.fillRect(lastMouseX-halfSize*rendMult, lastMouseY-halfSize*rendMult, halfSize*rendMult*2, halfSize*rendMult*2);
      drawThing(ctx, [x, y], 6);
      // ctx.fillStyle = "rgba(250,0,0, 0.7)";
      // var midSize = 4;
      // ctx.fillRect(lastMouseX-midSize/2, lastMouseY-midSize/2, midSize, midSize);
    },

    mySpawners: function(){
      return makeIdArr(state.worldState[SPAWNER.MINE]);
    },

    enemySpawners: function(){
      return makeIdArr(state.worldState[SPAWNER.OTHER]);
    },
    
    myBullets: function(){
      return makeIdArr( state.worldState[PROJECTILE.MINE] );
    },
    
    enemyBullets: function(){
      return makeIdArr(state.worldState[PROJECTILE.OTHER]);
    },
    
    credits: function(){
      return state.credits;
    }

  };

  var lastFrameTime = -1;

  function doFrame(t) {
    if (lastFrameTime !== -1) {
      update(state, t-lastFrameTime);
      draw(canvas, ctx, state.worldState, state.resourceSlots, self.onDraw);
    }
    lastFrameTime = t;
    requestAnimationFrame(doFrame);
  }


  return self;
}


function drawThing(ctx, pos, halfSize) {
  ctx.beginPath();
  ctx.arc(pos[0], pos[1], halfSize*rendMult, 0, 2*Math.PI, false);
  ctx.fill();
  ctx.closePath();
}


function drawThings(ctx, col, things, halfSize) {
  ctx.fillStyle = "rgb("+col[0]+","+col[1]+","+col[2]+")";
  _.forOwn(things, function (p) {
    var drawPos = [p.pos[0]*rendMult, p.pos[1]*rendMult];
    drawThing(ctx, drawPos, halfSize);
  });
}


function draw(canvas, ctx, world, resourceSlots, onDraw) {
  ctx.clearRect(0,0,canvas.width, canvas.height);

  drawBuildArea(ctx, world[SPAWNER.MINE], 245, 235, 235);
  drawBuildArea(ctx, world[DEFENSE.MINE], 245, 235, 235);
  drawBuildArea(ctx, resourceSlots, 230,230,180);

  _.forOwn(world, function(thingArr, id){
    var inf = ThingInfos[id];
    drawThings(ctx, inf.col, thingArr, inf.size);
  });

  if (onDraw) {
    onDraw();
  }
}


function drawAreaForBuilding(ctx) {
  return function(b){
    if(b){
      ctx.beginPath();
      ctx.arc(b.pos[0]*rendMult, b.pos[1]*rendMult, BUILD_AREA_SIZE*rendMult, 0, 2*Math.PI, false);
      ctx.fill();
      ctx.closePath();
    }
  };
}


function drawBuildArea(ctx, buildings, r, g, b) {
  ctx.fillStyle = "rgb("+r+","+g+","+b+")";
  _.forOwn(buildings, drawAreaForBuilding(ctx));
}


function playerController(game) {
  var lastMouseX = 0;
  var lastMouseY = 0;


  game.onDraw = function () {
    game.drawCursorBuilding(lastMouseX, lastMouseY);
  };

  game.canvas.addEventListener('mousemove', function(ev){
    lastMouseX = ev.offsetX;
    lastMouseY= ev.offsetY;
  });

  window.addEventListener('keydown', function(e){
    var x = lastMouseX;
    var y = lastMouseY;
    if (e.key === 'q') {
      game.placeSpawner(x,y);
    }
    if (e.key === 'w') {
      game.placeDefense(x,y);
    }
    if (e.key === 'a') { // for dvorak
      game.placeDefense(x,y);
    }
  });


  game.canvas.addEventListener('click', function(ev){
    game.placeSpawner(ev.offsetX,ev.offsetY);
  });


  game.canvas.oncontextmenu = function(ev) {
    game.placeSpawner(ev.offsetX, ev.offsetY);
    return false; 
  };

}


function playerMain(canvasName) {
  msgArea = document.getElementById('messages');
  opponentsText = document.getElementById('opponents');
  var canvas = document.getElementById(canvasName);
  var nick = localStorage.getItem('nickName');
  canvas.style.visibility = nick?'visible':'hidden';
  if (nick) {
    playerController(runGame(canvas, nick));
  }else{
    nick = prompt("Nickname: ");
    if (nick) {
      localStorage.setItem('nickName', nick);
    }
    window.location.reload();
  }
}


function aiMain(canvasName, aiNick){
  aiController(runGame(document.getElementById(canvasName), aiNick));
}


function main() {
  playerMain('canvas1');
  // aiMain('canvas2', 'ai_dummy');
}


window.onload = main;


