function runPingPong(in)

if ~exist('in','var'); error('Need to run this from the GUI!'); end

try 
	in.task = lower(in.task);
	s = screenManager('distance',in.distance,'pixelsPerCm',in.ppc);
	s.backgroundColour = [0 0 0];
	if max(Screen('Screens')) == 0; s.windowed = [0 0 1000 800]; s.specialFlags = 0; end
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

	% DIVIDER WALL for Cooperation-Time
	dwall = clone(ped1);
	dwall.name = 'dwall';
	dwall.barWidth = in.dWidth;
	dwall.barHeight = sv.heightInDegrees - in.floor - in.ceiling;
	dwall.xPosition = 0;
	dwall.yPosition = 0 - (in.floor/2);

	% BALLS
	ball = imageStimulus('name','ball');
	ball.filePath = in.image;
	ball.xPosition = in.startA;
	ball.yPosition = ped1.yPosition - in.ballSize;
	ball.angle = 0;
	ball.speed = 0;
	ball.size = in.ballSize;
	ball2 = clone(ball);
	ball2.name = 'ball2';
	ball2.xPosition = in.startB;
	radius = ball.size/2;
	startx = ball.xPosition; starty = ball.yPosition;
	startx2 = ball2.xPosition; starty2 = ball2.yPosition;
	setup(ball, s); show(ball);
	setup(ball2, s); show(ball2);
	
	%===============================================ANIMATION MANAGER
	anim = animationManager('verbose', in.verbose);
	anim.timeDelta = sv.ifi*2;
	anim.rigidParams.linearDamping = in.linearD;
	
	%===this creates 4 walls, returns a metaStimulus we can use to draw the walls visually
	walls = anim.addScreenBoundaries(sv,[in.leftW in.ceiling in.rightW in.floor]);
	
	%===include our pedestals into this metaStimulus
	walls{walls.n+1} = ped1;
	walls{walls.n+1} = ped2;
	walls{walls.n+1} = dwall;

	%===make sure all our walls are the same colour
	edit(walls, 1:walls.n, 'colour', in.wallColour);
	
	%===setup the metaStimulus
	setup(walls, s); show(walls);

	%===add pedestals and ball to physics simulation
	anim.addBody(ped1,'Rectangle','infinite');
	anim.addBody(ped2,'Rectangle','infinite');
	if matches(in.task, ["control", "cooperationtime"])
		anim.addBody(dwall,'Rectangle','infinite');
	end

	%===get our wall bodies we can use for collision analysis
	[lwb, ~, lwbidx] = anim.getBody('leftwall');
	[clb, ~, clbidx] = anim.getBody('ceiling');
	[rwb, ~, rwbidx] = anim.getBody('rightwall');
	[flb, ~, flbidx] = anim.getBody('floor');
	[dlb, ~, dlbidx] = anim.getBody('dwall');

	%===add balls to physics world
	anim.addBody(ball,'Circle','normal');
	[ballb, ballidx] = anim.getBody('ball');
	if matches(in.task, ["control", "cooperationtime"])
		anim.addBody(ball2,'Circle','normal'); 
		[ball2b, ball2idx] = anim.getBody('ball2');
	end

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
	
	%===============================================TOUCH MANAGER
	%front
	tMF = touchManager('isDummy',in.dummy,'verbose',in.verbose,...
		'panelType',1);
	tMF.window.radius = radius; % taken from the ball
	tMF.window.X = startx; % lock to the ball position
	tMF.window.Y = starty; % lock to the ball position
	setup(tMF, s);
	createQueue(tMF);
	start(tMF);
	%back
	tMB = touchManager('isDummy',in.dummy,'verbose',in.verbose,...
		'panelType',2);
	tMB.window.radius = radius; % taken from the ball
	tMB.window.X = startx2; % lock to the ball position
	tMB.window.Y = starty2; % lock to the ball position
	if isscalar(tMB.names); tMB.isDummy = true; end
	setup(tMB, s);
	createQueue(tMB);
	start(tMB);
	
	%===============================================setup some other parameters
	nTrials = 100;
	nCorrect = 0;
	RestrictKeysForKbCheck(KbName('ESCAPE'));
	subject = [in.subjecta '-' in.subjectb];
	[pth, sID, dID, name] = getALF(s, subject,'CognitionPlatform',true); %me, subject, lab, create
	fileName = [name '.mat'];

	%===============================================bump our priority
	Priority(1);

	%===============================================our results structure
	anidata = struct('N',NaN,'t',[],'x',[],'y',[],'dx',[],'dy',[],...
		'ke',[],'pe',[]);
	results = struct('N',[],'correct',[],'wallPos',[],...
		'RT',[],'date',dID,'name',fileName,...
		'anidata',anidata);
	
	%===============================================
	%===============================================
	%===============================================
	for jj = 1:nTrials

		results.anidata(jj).N = jj;
		fprintf('≣≣≣≣⊱ Trial: %i\n', jj);
		ball.xPositionOut = startx;
		ball.yPositionOut = starty;
		ball.update;
		ball2.xPositionOut = startx2;
		ball2.yPositionOut = starty2;
		ball2.update;
		try ballb.setGravityScale(1); end
		try ball2b.setGravityScale(1); end
		
		tMF.window.X = ball.xFinalD;
		tMF.window.Y = ball.yFinalD;
		tMB.window.X = ball2.xFinalD;
		tMB.window.Y = ball2.yFinalD;
		
		% the animator needs to be updated to the ball on each trial
		update(anim);
		
		xy = []; tx = []; ty = []; iv = round(sv.fps/5);
		nowX = NaN; nowY = NaN;
		evt = []; evtB = [];
		correct = false;
		countDown = 20;
		correctCollideF = false;
		incorrectCollideF = false;
		correctCollideB = false;
		incorrectCollideB = false;
		inTouchF = false;
		inTouchB = false;
		needStepF = false;
		needStepB = false;
		drawBackground(s, s.backgroundColour);
		flush(tMF); flush(tMB)
		vbl = flip(s); tStart = vbl;
		
		switch lower(in.task)
			case 'control'
				doControl();
			case 'cooperation'
				doCooperation()
			case 'cooperationtime'
				doCooperationTime()
			case 'competition'
				doCompetition()
		end

		if KbCheck; break; end

		updateTrial();
		
	end

	Priority(0);
	RestrictKeysForKbCheck([]);
	disp(['≣≣≣≣⊱ DATA saving to ' fileName]);
	save(fileName,'results','in');
	try close(tMF); end %#ok<*TRYNC>
	try close(tMB); end %#ok<*TRYNC>
	try reset(ball); end
	try reset(ball2); end
	try reset(walls); end
	try reset(peds); end
	try close(s); end

	plot(in.axis1, results.anidata(end).x,results.anidata(end).y,'-');
	xlabel(in.axis1,'X Position');
	ylabel(in.axis1, 'Y Position');
	plot(in.axis2, results.N, results.correct,'.-');
	ylim(in.axis2,[-0.1 1.1]);

catch ERR
	getReport(ERR);
	Priority(0);
	RestrictKeysForKbCheck([]);
	try anim.reset; end
	try tMF.close; end
	try ball.reset; end
	try s.close; end
	try sca; end
	rethrow(ERR);
end

	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	function doControl()
		while ~correct && vbl < tStart + 60
			if KbCheck; break; end
			needStepF = false; needStepB = false;
			processFront();
			%processBack();
			doStep();
			[coll, otherBody] = isCollision(anim, ballb); % check collisions
			if coll && otherBody.hashCode == anim.bodies(rwbidx).hash
				correctCollideF = true;
			elseif coll && otherBody.hashCode == anim.bodies(lwbidx).hash
				incorrectCollideF = true;
			end
			if correctCollideF
				ballb.setGravityScale(100);
				countDown = countDown - 1;
				if countDown == 0
					correct = true;
				end
			elseif incorrectCollideF
				ballb.setGravityScale(100);
				countDown = countDown - 1;
				if countDown == 0
					break;
				end
			end
			draw(ball);
			draw(ball2);
			draw(walls);
			if in.verbose; drawGrid(s);drawScreenCenter(s);end
			vbl = flip(s, vbl + sv.halfifi);
			% save all animation data for each trial, we can use this to "play
			% back" the action performed by the monkey
			updateFrame();
		end
	end

	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	function doCooperation()
		while ~correct && vbl < tStart + 60
			if KbCheck; break; end
			needStepF = false; needStepB = false;
			processFront();
			processBack();
			doStep();
			[coll, otherBody] = isCollision(anim, ballb); % check collisions
			if coll && otherBody.hashCode == anim.bodies(rwbidx).hash
				correctCollide = true;
			elseif coll && otherBody.hashCode == anim.bodies(lwbidx).hash
				incorrectCollide = true;
			end
			if correctCollide
				ballb.setGravityScale(100);
				countDown = countDown - 1;
				if countDown == 0
					correct = true;
				end
			elseif incorrectCollide
				ballb.setGravityScale(100);
				countDown = countDown - 1;
				if countDown == 0
					break;
				end
			end
			draw(ball);
			draw(ball2);
			draw(walls);
			if in.verbose; drawGrid(s);drawScreenCenter(s);end
			vbl = flip(s, vbl + sv.halfifi);
			% save all animation data for each trial, we can use this to "play
			% back" the action performed by the monkey
			updateFrame();
		end
	end

	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	function doCooperationTime()
		while ~correct && vbl < tStart + 60
			if KbCheck; break; end
			needStepF = false; needStepB = false;
			processFront();
			processBack();
			doStep();
			[coll, otherBody] = isCollision(anim, ballb); % check collisions
			if coll && otherBody.hashCode == anim.bodies(rwbidx).hash
				correctCollide = true;
			elseif coll && otherBody.hashCode == anim.bodies(lwbidx).hash
				incorrectCollide = true;
			end
			if correctCollide
				ballb.setGravityScale(100);
				countDown = countDown - 1;
				if countDown == 0
					correct = true;
				end
			elseif incorrectCollide
				ballb.setGravityScale(100);
				countDown = countDown - 1;
				if countDown == 0
					break;
				end
			end
			draw(ball);
			draw(ball2);
			draw(walls);
			if in.verbose; drawGrid(s);drawScreenCenter(s);end
			vbl = flip(s, vbl + sv.halfifi);
			% save all animation data for each trial, we can use this to "play
			% back" the action performed by the monkey
			updateFrame();
		end
	end

	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	function doCompetition()
		while ~correct && vbl < tStart + 60
			if KbCheck; break; end
			needStepF = false; needStepB = false;
			processFront();
			processBack();
			doStep();
			[coll, otherBody] = isCollision(anim, ballb); % check collisions
			if coll && otherBody.hashCode == anim.bodies(rwbidx).hash
				correctCollide = true;
			elseif coll && otherBody.hashCode == anim.bodies(lwbidx).hash
				incorrectCollide = true;
			end
			if correctCollide
				ballb.setGravityScale(100);
				countDown = countDown - 1;
				if countDown == 0
					correct = true;
				end
			elseif incorrectCollide
				ballb.setGravityScale(100);
				countDown = countDown - 1;
				if countDown == 0
					break;
				end
			end
			draw(ball);
			draw(ball2);
			draw(walls);
			if in.verbose; drawGrid(s); drawScreenCenter(s); end
			vbl = flip(s, vbl + sv.halfifi);
			% save all animation data for each trial, we can use this to "play
			% back" the action performed by the monkey
			updateFrame();
		end
	end

	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	function doStep()
		if needStepF || needStepB
			step(anim);
			if needStepF
				ball.updateXY(anim.x(1), anim.y(1), true);
				a = anim.angularVelocity(ballidx);
				ball.angleOut = ball.angleOut + (rad2deg(a) * anim.timeDelta);
			end
			if needStepB && length(anim.x)==2
				ball2.updateXY(anim.x(2), anim.y(2), true);
				a = anim.angularVelocity(ball2idx);
				ball2.angleOut = ball2.angleOut + (rad2deg(a) * anim.timeDelta);
			end
		end
	end

	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	function processFront()
		tM = tMF;
		if tM.eventAvail % check we have touch event[s]
			tM.window.X = ball.xFinalD;
			tM.window.Y = ball.yFinalD;
			tch = checkTouchWindows(tM); % check we are in touch window
			if tch; inTouchF = true; end
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
						ln, ball.xFinal, evt.MappedX, anim.x, x, vx, ball.yFinal, evt.MappedY, anim.y, y, vy, av); end
					anim.editBody(ballb,x,y,vx,vy,av);
				end
				needStepF = true;
				xy = []; tx = []; ty = []; inTouchF = false;
			elseif inTouchF && ~isempty(evt) && evt.Type > 1 && evt.Type < 4
				checkLimits(limits(1:4),ball,evt);
				tx = [tx nowX];
				ty = [ty nowY];
				anim.editBody(ballb, nowX, nowY);
			else
				needStepF = true;
			end
		else % no touch events are available, just run the physics engine
			needStepF = true;
		end
	end

	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	function processBack()
		tM = tMF;
		if tM.eventAvail % check we have touch event[s]
			tM.window.X = ball.xFinalD;
			tM.window.Y = ball.yFinalD;
			tch = checkTouchWindows(tM); % check we are in touch window
			if tch; inTouchF = true; end
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
						ln, ball2.xFinal, evtB.MappedX, anim.x(2), x, vx, ball2.yFinal, evtB.MappedY, anim.y(2), y, vy, av); end
					anim.editBody(ball2b,x,y,vx,vy,av);
				end
				needStepF = true;
				xy = []; tx = []; ty = []; inTouchF = false;
			elseif inTouchF && ~isempty(evtB) && evtB.Type > 1 && evtB.Type < 4
				checkLimits(limits(1:4),ball2,evtB);
				tx = [tx nowX];
				ty = [ty nowY];
				anim.editBody(ball2b,nowX,nowY);
			else
				needStepF = true;
			end
		else % no touch events are available, just run the physics engine
			needStepF = true;
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
	function checkDivider()

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
			drawBackground(s, [0.3 0.6 0.3]);
			flip(s);
			giveReward(rwdFront);
			beep(aM, 3000,0.1,0.1);
			disp('≣≣≣≣⊱ CORRECT');
			WaitSecs('Yieldsecs',2);
		else
			disp('≣≣≣≣⊱ FAIL');
			beep(aM, 300,0.5,0.5);
			drawBackground(s, [0.6 0.3 0.3]);
			flip(s);
			WaitSecs('Yieldsecs',3);
		end
	
		plot(in.axis1, results.anidata(end).x,results.anidata(end).y,'-');
		if isfield(results.anidata,'x2')
			hold on
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