function runPingPong(in)

if ~exist('in','var'); error('Need to run this from the GUI!'); end

try 
	in.task = lower(in.task);
	in.side = lower(in.side);
	s = screenManager('distance',in.distance,'pixelsPerCm',in.ppc);
	s.backgroundColour = [0 0 0];
	if max(Screen('Screens')) == 0 && in.verbose
		PsychDebugWindowConfiguration([],0.6);
	end
	sv = open(s);
	
	%==============================================Arduino initialization
	rwdFront = arduinoManager('port',in.arduinoa,'shield','new');
	if isempty(in.arduinoa); rwdFront.silentMode = true; end
	rwdFront.open;

	rwdBack = arduinoManager('port',in.arduinob,'shield','new');
	if isempty(in.arduinob); rwdBack.silentMode = true; end
	rwdBack.open;
	
	%==============================================Audio Manager
	if ~exist('aM','var') || isempty(aM) || ~isa(aM,'audioManager')
		aM = audioManager;
	end
	aM.silentMode = false;
	if ~aM.isSetup;	aM.setup; end
	
	%==============================================BALLS and PEDESTALS
	% PEDESTALS
	ped1 = barStimulus('name','ped1');
	ped1.colour = in.wallColour;
	ped1.alpha = 1.0;
	ped1.type = 'solid';
	ped1.scaleTexture = 5;
	ped1.barWidth = 4;
	ped1.barHeight = 2;
	ped1.xPosition = in.startA;
	ped1.yPosition = sv.bottomInDegrees - in.floor - (ped1.barHeight/2);
	ped2 = clone(ped1);
	ped2.name = 'ped2';
	ped2.xPosition = in.startB;

	% DIVIDER WALL(S)
	dwallF = clone(ped1);
	dwallF.name = 'dwallF';
	dwallF.barWidth = in.dWidth/2;
	dwallF.barHeight = sv.heightInDegrees - in.floor - in.ceiling;
	dwallF.xPosition = 0 - (dwallF.barWidth/2);
	dwallF.yPosition = 0 - (in.floor/2);
	dwallB = clone(dwallF);
	dwallB.name = 'dwallB';
	dwallB.xPosition = 0 + (dwallB.barWidth/2);

	% BALLS
	ballF = imageStimulus('name','ballF');
	ballF.filePath = in.image;
	ballF.xPosition = in.startA;
	ballF.yPosition = ped1.yPosition - in.ballSize;
	ballF.angle = 0;
	ballF.speed = 0;
	ballF.size = in.ballSize;
	ballB = clone(ballF);
	ballB.name = 'ballB';
	ballB.xPosition = in.startB;
	radius = ballF.size/2;
	startx = ballF.xPosition; starty = ballF.yPosition;
	startx2 = ballB.xPosition; starty2 = ballB.yPosition;
	setup(ballF, s); show(ballF);
	setup(ballB, s); show(ballB);
	
	%===============================================ANIMATION MANAGER
	anim = animationManager('verbose', in.verbose);
	anim.timeDelta = sv.ifi*2;
	anim.rigidParams.linearDamping = in.linearD;
	
	%===this creates 4 walls, returns a metaStimulus we can use to draw the walls visually
	walls = anim.addScreenBoundaries(sv,[in.leftW in.ceiling in.rightW in.floor]);
	
	%===include our pedestals into this metaStimulus
	walls{walls.n+1} = ped1;
	walls{walls.n+1} = ped2;
	walls{walls.n+1} = dwallF;
	walls{walls.n+1} = dwallB;

	%===make sure all our walls are the same colour
	edit(walls, 1:walls.n, 'colour', in.wallColour);
	
	%===setup the metaStimulus
	setup(walls, s); show(walls);

	%===add pedestals and ball to physics simulation
	anim.addBody(ped1,'Rectangle','infinite');
	anim.addBody(ped2,'Rectangle','infinite');
	if ~matches(in.task, ["control", "cooperation"])
		anim.addBody(dwallF,'Rectangle','infinite');
		anim.addBody(dwallB,'Rectangle','infinite');
		show(dwallF); show(dwallB);
	else
		%balls cannot collide with a sensor, we keep the world the same 
		% just make divider wall transparant to other objects
		anim.addBody(dwallF,'Rectangle','sensor'); 
		anim.addBody(dwallB,'Rectangle','sensor'); 
		hide(dwallF); hide(dwallB);
	end

	%===get our wall bodies we can use for collision analysis
	[lwb, ~, lwidx, ~, lwhash] = anim.getBody('leftwall');
	[clb, ~, clidx, ~, clhash] = anim.getBody('ceiling');
	[rwb, ~, rwidx, ~, rwhash] = anim.getBody('rightwall');
	[flb, ~, flidx, ~, flhash] = anim.getBody('floor');
	[dwfb, ~, dwfidx, ~, dwfhash] = anim.getBody('dwallF');
	[dwbb, ~, dwbidx, ~, dwbhash] = anim.getBody('dwallB');

	%===add balls to physics world
	anim.addBody(ballF,'Circle','bullet');
	[ballFb, ballFidx] = anim.getBody('ballF');
	anim.addBody(ballB,'Circle','bullet'); 
	[ballBb, ballBidx] = anim.getBody('ballB');

	%===setup our physics world
	setup(anim, s);

	%===============================================DEFINE TOUCH LIMITS
	limits(1).id = "ygt"; %floor
	limits(1).val = walls{4}.yPosition - (walls{4}.barHeight/2) - radius;
	limits(1).pxval = toPixels(s,limits(1).val,'y');
	limits(2).id = "ylt"; %ceiling
	limits(2).val = walls{2}.yPosition + (walls{2}.barHeight/2) + radius;
	limits(2).pxval = toPixels(s,limits(2).val,'y');
	limits(3).id = "xlt"; %leftwall
	limits(3).val = walls{1}.xPosition + (walls{1}.barWidth/2) + radius;
	limits(3).pxval = toPixels(s,limits(3).val,'x');
	limits(4).id = "xgt"; %rightwall
	limits(4).val = walls{3}.xPosition - (walls{3}.barWidth/2) - radius;
	limits(4).pxval = toPixels(s,limits(4).val,'x');
	% divider limits
	limits(5).id = "xgt";
	limits(5).val = walls{7}.xPosition - (walls{7}.barWidth/2) - radius;
	limits(5).pxval = toPixels(s,limits(5).val,'x');
	limits(6).id = "xlt";
	limits(6).val = walls{7}.xPosition + (walls{7}.barWidth/2) + radius;
	limits(6).pxval = toPixels(s,limits(6).val,'x');
	limits(7).id = "xgt";
	limits(7).val = walls{8}.xPosition - (walls{8}.barWidth/2) - radius;
	limits(7).pxval = toPixels(s,limits(7).val,'x');
	limits(8).id = "xlt";
	limits(8).val = walls{8}.xPosition + (walls{8}.barWidth/2) + radius;
	limits(8).pxval = toPixels(s,limits(8).val,'x');
	
	%===============================================TOUCH MANAGER
	%front
	tMF = touchManager('device',1,'panelType',1,...
		'isDummy',in.dummy,'verbose',in.verbose);
	tMF.window.radius = radius; % taken from the ball
	tMF.window.X = startx; % lock to the ball position
	tMF.window.Y = starty; % lock to the ball position
	setup(tMF, s);
	createQueue(tMF);
	start(tMF);
	%back
	tMB = touchManager('device',2,'panelType',2,...
		'isDummy',in.dummy,'verbose',in.verbose);
	tMB.window.radius = radius; % taken from the ball
	tMB.window.X = startx2; % lock to the ball position
	tMB.window.Y = starty2; % lock to the ball position
	if isempty(tMB.names) || isscalar(tMB.names); tMB.isDummy = true; tMB.panelType = 1; end % only activate if more than 1 touchscreen
	setup(tMB, s);
	createQueue(tMB);
	start(tMB);
	
	%===============================================setup some other parameters
	nTrials = 100;
	nCorrect = 0;
	RestrictKeysForKbCheck(KbName('ESCAPE'));
	subject = [in.subjecta '-' in.subjectb];
	[pth, sID, dID, name] = getALF(s, subject,'CognitionPlatform',true); %me, subject, lab, create
	fileName = [pth 'PingPong' name '.mat'];

	%===============================================bump our priority
	Priority(1);

	%===============================================our results structure
	anidata = struct('N',NaN,'t',[],'x',[],'y',[],'dx',[],'dy',[],...
		'ke',[],'pe',[]);
	results = struct('N',[],'correct',[],'wallPos',[],...
		'RT',[],'date',dID,'name',fileName,...
		'anidata',anidata);

	%===============================================LOGIC FOR TASKS
	onlyFront = false; onlyBack = false; bothSides = false;
	if matches(in.side,'back')
		onlyBack = true;
	elseif matches(in.side,'front')
		onlyFront = true;
	elseif matches(in.side,'both')
		bothSides = true;
	elseif in.dummy
		bothSides = true;
	end
	if matches(in.task,["coaction","cooperation","cooperationtime","competition"]) && ~bothSides
		warning("For these Tasks you must use both sides of the touch screen!!!")
		onlyFront = false; onlyBack = false; bothSides = true;
	end

	coopPhase = 1;
	
	%===============================================
	%===============================================
	%===============================================
	for jj = 1:nTrials

		results.anidata(jj).N = jj;
		fprintf('≣≣≣≣⊱ Trial: %i\n', jj);

		switch (in.task)
			case 'control'
				hide(dwallF); hide(dwallB);
				if onlyBack
					hide(ballF);
					show(ballB);
					ballB.xPositionOut = startx2;
					ballB.yPositionOut = starty2;
					anim.editBody(ballBb, startx2, starty2);
					ballFb.setEnabled(false);
					ballBb.setEnabled(true);
					anim.setSensorState('ballF',true);
				elseif onlyFront
					hide(ballB);
					show(ballF);
					ballF.xPositionOut = startx;
					ballF.yPositionOut = starty;
					anim.editBody(ballFb, startx, starty);
					ballFb.setEnabled(true);
					ballBb.setEnabled(false);
					anim.setSensorState('ballB',true);
				end
			case 'coaction'
				show(dwallF); show(dwallB);
				show(ballF);
				show(ballB);
				ballF.xPositionOut = startx;
				ballF.yPositionOut = starty;
				ballB.xPositionOut = startx2;
				ballB.yPositionOut = starty2;
				anim.editBody(ballFb,startx,starty);
				anim.editBody(ballBb,startx2,starty2);
			case 'cooperation'
				coopPhase = 1; % there are two phases, 1 is monkeyA and 2 is monkeyB
				hide(dwall);
				show(ballF)
				hide(ballB)
				ballF.xPositionOut = startx;
				ballF.yPositionOut = starty;
				ballB.xPositionOut = startx2;
				ballB.yPositionOut = -100;
				anim.editBody(ballFb,startx,starty);
				anim.editBody(ballBb,-100,starty2);
			case 'cooperationtime'
				show(dwall);
				show(ballF);
				show(ballB);
				ballF.xPositionOut = startx;
				ballF.yPositionOut = starty;
				ballB.xPositionOut = startx2;
				ballB.yPositionOut = starty2;
				anim.editBody(ballFb,startx,starty);
				anim.editBody(ballBb,startx2,starty2);
			case 'competition'
				show(dwall);
				show(ballF)
				show(ballB)
				ballF.xPositionOut = startx;
				ballF.yPositionOut = starty;
				ballB.xPositionOut = startx2;
				ballB.yPositionOut = starty2;
				anim.editBody(ballFb,startx,starty);
				anim.editBody(ballBb,startx2,starty2);
		end
		
		edit(walls, 1:walls.n, 'colourOut', in.wallColour);
		ballF.update();
		ballB.update();
		walls.update();

		try ballFb.setGravityScale(1); end
		try ballBb.setGravityScale(1); end
		
		% update touchManager window with ball positions
		tMF.window.X = ballF.xFinalD;
		tMF.window.Y = ballF.yFinalD;
		tMB.window.X = ballB.xFinalD;
		tMB.window.Y = ballB.yFinalD;
		
		% the animator needs to be updated to reset the physics world
		anim.update();

		xy = []; tx = []; ty = []; iv = round(sv.fps/5);
		nowX = NaN; nowY = NaN;
		evt = []; evtB = [];
		collF = false; otherBodyF = [];
		collB = false; otherBodyB = [];
		correct = false; correctF = false; correctB = false;
		countDownF = 60; countDownB = 60;
		correctCollideF = false;
		incorrectCollideF = false;
		correctCollideB = false;
		incorrectCollideB = false;
		inTouchF = false;
		inTouchB = false;
		stepF = false;
		stepB = false;
		drawBackground(s, s.backgroundColour);
		flush(tMF); flush(tMB);

		%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
		%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%RUN OUR TRIAL
		%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
		vbl = flip(s); tStart = vbl;
		switch (in.task)
			case 'control'
				doControl();
			case 'coaction'
				doCoaction();
			case 'cooperation'
				doCooperation()
			case 'cooperationtime'
				doCooperationTime()
			case 'competition'
				doCompetition()
		end
		%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
		%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
		%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

		if KbCheck; break; end

		updateTrial();
		
	end

	drawTextNow(s,'!!! FINISHED !!!',0,0);
	Priority(0);
	RestrictKeysForKbCheck([]);
	try close(s); end
	try close(tMF); end %#ok<*TRYNC>
	try close(tMB); end %#ok<*TRYNC>
	try reset(ballF); end
	try reset(ballB); end
	try reset(walls); end
	clear Screen

	fprintf('\n\n≣≣≣≣⊱ DATA saving to %s\n', fileName);
	save(fileName,'results','in');

	plot(in.axis1, results.anidata(end).x,results.anidata(end).y,'-');
	xlabel(in.axis1,'X Position');
	ylabel(in.axis1, 'Y Position');
	plot(in.axis2, results.N, results.correct,'.-');
	ylim(in.axis2,[-0.1 1.1]);

catch ERR
	getReport(ERR);
	Priority(0); ShowCursor;
	RestrictKeysForKbCheck([]);
	try s.close; end
	try anim.reset; end
	try tMF.close; end
	try tMB.close; end
	try rwdFront.close; end
	try rwdBack.close; end
	try ballF.reset; ballB.reset; end
	try sca; end
	rethrow(ERR);
end

	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	function doControl()
		while ~correct && vbl < tStart + 60
			if KbCheck; break; end
			stepF = false; stepB = false;
			if onlyFront && (~incorrectCollideF && ~correctCollideF)
				processFront();
				doStep();
				[collF, otherBodyF] = isCollision(anim, ballFb); % check collisions
				checkWallsF();
			elseif onlyBack && (~incorrectCollideB && ~correctCollideB)
				processBack();
				doStep();
				[collB, otherBodyB] = isCollision(anim, ballBb); % check collisions
				checkWallsB();
			else
				if onlyFront; stepF = true; else; stepB = true; end
				doStep();
			end 
			updateWalls();
			if onlyFront
				draw(ballF); 
			elseif onlyBack
				draw(ballB); 
			end
			draw(walls);
			if in.verbose; drawGrid(s); drawScreenCenter(s); end
			vbl = flip(s, vbl + sv.halfifi);
			% save all animation data for each trial, we can use this to "play
			% back" the action performed by the monkey
			updateFrame();
			if countDownF == 0 || countDownB == 0
				if correctCollideF
					correct = true; correctF = true; break
				end
				if correctCollideB
					correct = true; correctB = true; break
				end
				if incorrectCollideF || incorrectCollideB
					break
				end
			end 
		end
	end

	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	function doCoaction()
		while ~correct && vbl < tStart + 60
			if KbCheck; break; end
			stepF = false; stepB = false;
			processFront(); processBack();
			[collF, otherBodyF] = isCollision(anim, ballFb); % check collisions
			[collB, otherBodyB] = isCollision(anim, ballBb); % check collisions
			doStep();
			checkDivider();
			updateWalls();
			draw(ballF); draw(ballB); 
			draw(walls);
			if in.verbose; drawGrid(s); drawScreenCenter(s); end
			vbl = flip(s, vbl + sv.halfifi);
			% save all animation data for each trial, we can use this to "play
			% back" the action performed by the monkey
			updateFrame();
			if countDownF == 0 || countDownB == 0
				if correctCollideF
					correct = true; correctF = true; break
				end
				if correctCollideB
					correct = true; correctB = true; break
				end
				if incorrectCollideF || incorrectCollideB
					break
				end
			end 
		end
	end

	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	function doCooperationTime()
		while ~correct && vbl < tStart + 60
			if KbCheck; break; end
			stepF = false; stepB = false;
			if onlyFront && (~incorrectCollideF && ~correctCollideF)
				processFront();
				doStep();
				[coll, otherBody] = isCollision(anim, ballFb); % check collisions
				checkWallsF();
			elseif onlyBack && (~incorrectCollideB && ~correctCollideB)
				processBack();
				doStep();
				[coll, otherBody] = isCollision(anim, ballBb); % check collisions
				checkWallsB();
			else
				if onlyFront; stepF = true; else; stepB = true; end
				doStep();
			end 
			updateWalls();
			if onlyFront
				draw(ballF); 
			elseif onlyBack
				draw(ballB); 
			end
			draw(walls);
			if in.verbose; drawGrid(s); drawScreenCenter(s); end
			vbl = flip(s, vbl + sv.halfifi);
			% save all animation data for each trial, we can use this to "play
			% back" the action performed by the monkey
			updateFrame();
			if countDownF == 0 || countDownB == 0
				if correctCollideF
					correct = true; correctF = true; break
				end
				if correctCollideB
					correct = true; correctB = true; break
				end
				if incorrectCollideF || incorrectCollideB
					break
				end
			end 
		end
	end

	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	function doCompetition()
		while ~correct && vbl < tStart + 60
			if KbCheck; break; end
			stepF = false; stepB = false;
			if onlyFront && (~incorrectCollideF && ~correctCollideF)
				processFront();
				doStep();
				[coll, otherBody] = isCollision(anim, ballFb); % check collisions
				checkWallsF();
			elseif onlyBack && (~incorrectCollideB && ~correctCollideB)
				processBack();
				doStep();
				[coll, otherBody] = isCollision(anim, ballBb); % check collisions
				checkWallsB();
			else
				if onlyFront; stepF = true; else; stepB = true; end
				doStep();
			end 
			updateWalls();
			if onlyFront
				draw(ballF); 
			elseif onlyBack
				draw(ballB); 
			end
			draw(walls);
			if in.verbose; drawGrid(s); drawScreenCenter(s); end
			vbl = flip(s, vbl + sv.halfifi);
			% save all animation data for each trial, we can use this to "play
			% back" the action performed by the monkey
			updateFrame();
			if countDownF == 0 || countDownB == 0
				if correctCollideF
					correct = true; correctF = true; break
				end
				if correctCollideB
					correct = true; correctB = true; break
				end
				if incorrectCollideF || incorrectCollideB
					break
				end
			end 
		end
	end

	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	function doStep()
		if stepF || stepB
			step(anim);
			x = anim.x; y = anim.y;
			if stepF
				ballF.updateXY(x(1), y(1), true);
				a = anim.angularVelocity(ballFidx);
				ballF.angleOut = ballF.angleOut + (rad2deg(a) * anim.timeDelta);
			end
			if stepB 
				if isscalar(x)
					ballB.updateXY(x, y, true);
				else
					ballB.updateXY(x(2), y(2), true);
				end
				a = anim.angularVelocity(ballBidx);
				ballB.angleOut = ballB.angleOut + (rad2deg(a) * anim.timeDelta);
			end
		end
	end

	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	function processFront()
		tM = tMF;
		if tM.eventAvail % check we have touch event[s]
			tM.window.X = ballF.xFinalD;
			tM.window.Y = ballF.yFinalD;
			[tch, ~, wasEvent] = checkTouchWindows(tM); % check we are in touch window
			if ~wasEvent; return; end
			if tch == true; inTouchF = true; end
			evt = tM.event;
			nowX = tM.x; nowY = tM.y;
			if evt.Type == 4 % this is a RELEASE event
				if in.verbose; fprintf('≣≣≣≣⊱ processFront:RELEASE X: %.1f Y: %.1f \n',nowX,nowY); end
				if length(tx) >= 3 %collected enough samples
					ln = length(tx); if ln > iv; ln = iv; end
					xy = [tx(end-(ln-1):end)' ty(end-(ln-1):end)'];
					vx = mean(diff(xy(:,1))) * ln * in.sensitivity;
					vy = mean(diff(xy(:,2))) * ln * in.sensitivity;
					av = vx / 2;
					x = xy(end,1);
					y = xy(end,2);
					if in.verbose; fprintf('≣≣≣≣⊱ processFront:UPDATE X%i: stim:%.1f evt:%.1f anim:%.1f n:%.1f v:%.1f Y: stim:%.1f evt:%.1f anim:%.1f n:%.1f v:%.1f A: %.1f\n', ...
						ln, ballF.xFinal, evt.MappedX, anim.x, x, vx, ballF.yFinal, evt.MappedY, anim.y, y, vy, av); end
					anim.editBody(ballFb,x,y,vx,vy,av);
				end
				stepF = true;
				xy = []; tx = []; ty = []; inTouchF = false;
			elseif inTouchF && ~isempty(evt) && evt.Type > 1 && evt.Type < 4
				checkLimits(limits(1:4),ballF,evt);
				tx = [tx nowX];
				ty = [ty nowY];
				anim.editBody(ballFb, nowX, nowY);
			else
				stepF = true;
			end
		else % no touch events are available, just run the physics engine
			stepF = true;
		end
	end

	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	function processBack()
		tM = tMB;
		if tM.eventAvail % check we have touch event[s]
			tM.window.X = ballB.xFinalD;
			tM.window.Y = ballB.yFinalD;
			tch = checkTouchWindows(tM); % check we are in touch window
			if tch; inTouchB = true; end
			evtB = tM.event;
			nowX = tM.x; nowY = tM.y;
			if evtB.Type == 4 % this is a RELEASE event
				if in.verbose; fprintf('≣≣≣≣⊱ processBack:RELEASE X: %.1f Y: %.1f \n',nowX,nowY); end
				if length(tx) >= 3 %collected enough samples
					ln = length(tx); if ln > iv; ln = iv; end
					xy = [tx(end-(ln-1):end)' ty(end-(ln-1):end)'];
					vx = mean(diff(xy(:,1))) * ln * in.sensitivity;
					vy = mean(diff(xy(:,2))) * ln * in.sensitivity;
					av = vx / 2;
					x = xy(end,1);
					y = xy(end,2);
					if in.verbose; fprintf('≣≣≣≣⊱ processBack:UPDATE X%i: stim:%.1f evt:%.1f anim:%.1f n:%.1f v:%.1f Y: stim:%.1f evt:%.1f anim:%.1f n:%.1f v:%.1f A: %.1f\n', ...
						ln, ballB.xFinal, evtB.MappedX, anim.x(2), x, vx, ballB.yFinal, evtB.MappedY, anim.y(2), y, vy, av); end
					anim.editBody(ballBb,x,y,vx,vy,av);
				end
				stepB = true;
				xy = []; tx = []; ty = []; inTouchB = false;
			elseif inTouchB && ~isempty(evtB) && evtB.Type > 1 && evtB.Type < 4
				checkLimits(limits(1:4),ballB,evtB);
				tx = [tx nowX];
				ty = [ty nowY];
				anim.editBody(ballBb,nowX,nowY);
			else
				stepB = true;
			end
		else % no touch events are available, just run the physics engine
			stepB = true;
		end
	end

	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	function checkLimits(inlimits,inball,inevt)
		newX = []; newY = []; pxX = []; pxY = [];
		for jjj = 1:length(inlimits)
			val = inlimits(jjj).val; px = inlimits(jjj).pxval;
			switch inlimits(jjj).id
				case "ygt"
					if nowY > val; newY = val; pxY = px; end
				case "ylt"
					if nowY < val; newY = val; pxY = px; end
				case "xlt"
					if nowX < val; newX = val; pxX = px; end
				case "xgt"
					if nowX > val; newX = val; pxX = px; end
			end
		end
		if ~isempty(newX) && ~isempty(newY)
			nowX = newX; nowY = newY;
			inball.updateXY(pxX, pxY, false);
		elseif ~isempty(newX) 
			nowX = newX;
			inball.updateXY(pxX, inevt.MappedY, false);
		elseif ~isempty(newY) 
			nowY = newY;
			inball.updateXY(inevt.MappedX, pxY, false);
		else
			inball.updateXY(inevt.MappedX, inevt.MappedY, false);
		end
	end

	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	function checkWallsF()
		if collF && otherBodyF.hashCode == rwhash
			correctCollideF = true; stepF = true;
		elseif collF && otherBodyF.hashCode == lwhash
			incorrectCollideF = true; stepF = true;
		end
	end

	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	function checkWallsB()
		if collB && otherBodyB.hashCode == lwhash
			correctCollideB = true; stepB = true;
		elseif collB && otherBodyB.hashCode == rwhash			
			incorrectCollideB = true; stepB = true;
		end
	end

	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	function checkDivider()
		if collF && ~isempty(otherBodyF) && otherBodyF.hashCode == dwfhash
			correctCollideF = true;
		elseif collB && ~isempty(otherBodyB) && otherBodyB.hashCode == dwbhash
			correctCollideB = true;
		elseif collF
			%incorrectCollideF = true;
		elseif collB
			%incorrectCollideB = true;
		end
	end

	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	function updateWalls()
		if onlyFront || bothSides
			if correctCollideF
				walls{3}.colourOut = [0.3 0.7 0 1]; walls{3}.refreshTexture();
				ballFb.setGravityScale(100);
				countDownF = countDownF - 1;
				if countDownF == 0
					walls{3}.colourOut = [in.wallColour]; walls{3}.refreshTexture();
					hide(ballF); draw(walls);
					flip(s);
				end
			elseif incorrectCollideF
				walls{1}.colourOut = [1 0 0.3 1]; walls{1}.refreshTexture();
				ballFb.setGravityScale(100);
				countDownF = countDownF - 1;
				if countDownF == 0
					walls{1}.colourOut = [in.wallColour]; walls{1}.refreshTexture();
					hide(ballF); draw(walls);
					flip(s);
				end
			end
		end
		if onlyBack || bothSides
			if correctCollideB
				walls{1}.colourOut = [0.3 0.7 0 1]; walls{1}.refreshTexture();
				ballBb.setGravityScale(100);
				countDownB = countDownB - 1;
				if countDownB == 0
					walls{1}.colourOut = [in.wallColour]; walls{1}.refreshTexture();
					hide(ballB); draw(walls);
					flip(s); 
				end
			elseif incorrectCollideB
				walls{3}.colourOut = [1 0 0.3 1]; walls{3}.refreshTexture();
				ballBb.setGravityScale(100);
				countDownB = countDownB - 1;
				if countDownB == 0
					walls{3}.colourOut = [in.wallColour]; walls{3}.refreshTexture();
					hide(ballB); draw(walls);
					flip(s); 
				end
			end
		end
	end

	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	function updateDivider()
		if onlyFront || bothSides
			if correctCollideF
				dwallF.colourOut = [0.3 0.7 0 1]; dwallF.refreshTexture();
				ballFb.setGravityScale(100);
				countDownF = countDownF - 1;
				if countDownF == 0
					dwallF.colourOut = [in.wallColour]; dwallF.refreshTexture();
					hide(ballF);
				end
			end
		end
		if onlyBack || bothSides
			if correctCollideB
				dwallB.colourOut = [0.3 0.7 0 1]; dwallB.refreshTexture();
				ballBb.setGravityScale(100);
				countDownB = countDownB - 1;
				if countDownB == 0
					dwallB.colourOut = [in.wallColour]; dwallB.refreshTexture();
					hide(ballB); 
				end
			end
		end
	end

	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	function updateFrame()
		results.anidata(jj).t =  [results.anidata(jj).t, anim.timeStep];
		results.anidata(jj).x =  [results.anidata(jj).x, anim.x(1)];
		results.anidata(jj).y =  [results.anidata(jj).y, anim.y(1)];
		if length(anim.x) == 2
			results.anidata(jj).x2 =  [results.anidata(jj).x, anim.x(2)];
			results.anidata(jj).y2 =  [results.anidata(jj).y, anim.y(2)];
		end
		results.anidata(jj).dx = [results.anidata(jj).dx, anim.dX];
		results.anidata(jj).dy = [results.anidata(jj).dy, anim.dY];
		results.anidata(jj).ke = [results.anidata(jj).ke, anim.kineticEnergy];
		results.anidata(jj).pe = [results.anidata(jj).pe, anim.potentialEnergy];
	end

	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	function updateTrial()
		results.N = [results.N jj];
		results.correct = [results.correct correct];
		results.wallPos = [results.wallPos 1];
		results.RT = [results.RT (tStart - GetSecs)];
	
		if correct
			nCorrect = nCorrect + 1;
			disp('≣≣≣≣⊱ CORRECT');
			beep(aM, 3000,0.1,0.1);
			drawBackground(s, [0.3 0.6 0.3]);
			flip(s);
			if correctF
				giveReward(rwdFront);
			end
			if correctB
				giveReward(rwdBack);
			end
			WaitSecs('Yieldsecs',1);
			drawBackground(s, s.backgroundColour); draw(walls); flip(s); 
		else
			disp('≣≣≣≣⊱ FAIL');
			beep(aM, 400,0.7,0.7);
			drawBackground(s, [0.6 0.3 0.3]);
			flip(s);
			WaitSecs('Yieldsecs',1);
			drawBackground(s, s.backgroundColour); draw(walls); flip(s); 
			WaitSecs('Yieldsecs',2);
		end

		drawBackground(s, s.backgroundColour); draw(walls); flip(s); 
	
		plot(in.axis1, results.anidata(end).x,results.anidata(end).y,'-');
		if isfield(results.anidata,'x2')
			hold(in.axis1, "on");
			plot(in.axis1, results.anidata(end).x2,results.anidata(end).y2,':');
		end
		xlabel(in.axis1,'X Position');
		ylabel(in.axis1, 'Y Position');
		axis(in.axis1,'ij');
		plot(in.axis2, results.N, results.correct,'.-');
		xlabel(in.axis2,'Trial');
		ylabel(in.axis2, 'Correct');
		drawnow limitrate nocallbacks
	
	end
	
	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	function array = push(array, value)
		array = [array value];
	end

end