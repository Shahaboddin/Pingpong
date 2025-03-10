 function runPingPong(in)

if ~exist('in','var'); error('Need to run this from the GUI!'); end
cla(in.axis1); cla(in.axis2); drawnow;
commandwindow;

correctITI = in.iticorrect;
incorrectITI = in.itiincorrect;

in.task = lower(in.task);
in.side = lower(in.side);
timeMultiplier = 1; % time multiplier

try 
	s = screenManager('distance',in.distance,'pixelsPerCm',in.ppc);
	s.backgroundColour = [0 0 0 1];
    if IsWin; s.disableSyncTests = true; end
	if max(Screen('Screens')) == 0 || in.debug
		s.screen = 0;
		if s.screen == 0 && in.debug
			PsychDebugWindowConfiguration([],0.6);
		end
	end
	sv = open(s);
	% [left, top, right, bottom]
	frontHalf = [sv.leftInDegrees sv.topInDegrees 0 sv.bottomInDegrees];
	backHalf = [0 sv.topInDegrees sv.rightInDegrees sv.bottomInDegrees];
	
	%==============================================Arduino initialization
	rwdFront = arduinoManager('port',in.arduinoa,'shield','new','verbose',in.verbose);
	if isempty(in.arduinoa); rwdFront.silentMode = true; end
    rwdFront.reward.type = in.fronttype;
    rwdFront.reward.time = 800;
	rwdFront.open;

	rwdBack = arduinoManager('port',in.arduinob,'shield','new','verbose',in.verbose);
	if isempty(in.arduinob); rwdBack.silentMode = true; end
    rwdBack.reward.type = in.backtype;
    rwdBack.reward.time = 300;
	rwdBack.open;

	%==============================================Audio Manager
	if ~exist('aM','var') || isempty(aM) || ~isa(aM,'audioManager')
		aM = audioManager;
	end
	aM.silentMode = false;
	if ~aM.isSetup;	aM.setup; end
	
	%==============================================BALLS and PEDESTALS
	%===PEDESTALS
	ped1 = barStimulus('name','ped1');
	ped1.colour = in.wallColour;
	ped1.alpha = 1.0;
	ped1.type = 'solid';
	ped1.scaleTexture = 5;
	ped1.barWidth = in.pedwidth;
	ped1.barHeight = in.pedheight;
	ped1.xPosition = in.startA;
	ped1.yPosition = sv.bottomInDegrees - in.floor - (ped1.barHeight/2);
	ped2 = clone(ped1);
	ped2.name = 'ped2';
	ped2.xPosition = in.startB;

	%===DIVIDER WALL(S)
	dwallF = clone(ped1);
	dwallF.name = 'dwallF';
	dwallF.barWidth = in.dWidth/2;
	dwallF.barHeight = sv.heightInDegrees - in.floor - in.ceiling;
	dwallF.xPosition = 0 - (dwallF.barWidth/2);
	dwallF.yPosition = 0 - (in.floor/2);
	dwallB = clone(dwallF);
	dwallB.name = 'dwallB';
	dwallB.xPosition = 0 + (dwallB.barWidth/2);

	%===BALLS
	ballF = imageStimulus('name','ballF');
	ballF.filePath = in.image;
	ballF.xPosition = in.startA;
	ballF.yPosition = ped1.yPosition - ped1.barHeight/2 - in.ballSize;
	ballF.angle = 0;
	ballF.speed = 0;
	ballF.size = in.ballSize;
	ballB = clone(ballF);
	ballB.name = 'ballB';
	%ballB.filePath = 'moon.png';
	ballB.xPosition = in.startB;
	radius = ballF.size/2;
	startXFront = ballF.xPosition; startYFront = ballF.yPosition;
	startXBack = ballB.xPosition; startYBack = ballB.yPosition;
	setup(ballF, s); show(ballF);
	setup(ballB, s); show(ballB);

	%===============================================ANIMATION MANAGER
	if isempty(in.nirsmartip)
		doIO = false;
		io = ioManager;
	else
		doIO = true;
		io = nirSmartManager();
		ip = strsplit(in.nirsmartip,':');
		io.ip = ip{1};
		io.port = str2double(ip{2});
		io.open;
	end
	
	%===============================================ANIMATION MANAGER
	anim = animationManager('verbose', in.verbose);
	anim.timeDelta = sv.ifi * timeMultiplier;
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
	[ballFbody, ballFidx] = anim.getBody('ballF');
	anim.addBody(ballB,'Circle','bullet'); 
	[ballBbody, ballBidx] = anim.getBody('ballB');

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
	%===divider limits
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
	%===front
	tMF = touchManager('device',1,'panelType',1,'name','FRONT',...
		'isDummy',in.dummy,'verbose',in.verbose);
	tMF.window.radius = radius; % taken from the ball
	tMF.window.X = startXFront; % lock to the ball position
	tMF.window.Y = startYFront; % lock to the ball position
	setup(tMF, s);
	createQueue(tMF);
	start(tMF);
	%===back
	tMB = touchManager('device',2,'panelType',2,'name','BACK',...
		'isDummy',in.dummy,'verbose',in.verbose);
	tMB.window.radius = radius; % taken from the ball
	tMB.window.X = startXBack; % lock to the ball position
	tMB.window.Y = startYBack; % lock to the ball position
	if isempty(tMB.names) || isscalar(tMB.names); tMB.isDummy = true; tMB.panelType = 1; end % only activate if more than 1 touchscreen
	setup(tMB, s);
	createQueue(tMB);
	start(tMB);
	
	%===============================================setup some other parameters
	nCorrectF = 0;
	nCorrectB = 0;
	RestrictKeysForKbCheck(KbName('ESCAPE'));
	subject = [in.subjecta '-' in.subjectb];
	[pth, sID, dID, name] = getALF(s, subject,'CognitionPlatform',true); %me, subject, lab, create
	fileName = [pth 'PingPong' name '.mat'];

	%===============================================bump our priority
	Priority(1);

	%===============================================our results structure
	anidata = struct('N',NaN,'t',[],'x',[],'y',[],'x2',[],'y2',[],'dx',[],'dy',[],...
		'ke',[],'pe',[]);
	results = struct('N',[],'correct',[],'correctF',[],'correctB',[],'wallPos',[],...
		'RT',[],'date',dID,'name',fileName,...
		'anidata',anidata,'coopPhase',[],'coopTimer',[],...
		'timerF',[],'timerB',[],'correctCollideF',[],...
		'incorrectCollideF',[],'correctCollideB',[],...
		'incorrectCollideB',[]);
	
	%===============================================LOGIC FOR TASKS
	rewardNow = false; didRewardFront = false; didRewardBack = false;
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
	
	%===============================================
	%===============================================
	%===============================================
	for jj = 1:in.ntrials

		results.anidata(jj).N = jj;
		fprintf('≣≣≣≣⊱ Trial: %i\n', jj);

		% reset wall colour
		edit(walls, 1:walls.n, 'colourOut', in.wallColour);

		%=== The animator needs to be updated to reset the physics world
		anim.update();

		%===Task Logic for each task
		switch (in.task)
			case 'control'
				rewardNow = true;
				hide(dwallF); hide(dwallB);
				splitScreen = false;
				if onlyBack
					show(anim, "ballB");
					hide(anim, "ballF");
					editBody(anim, "ballB", startXBack, startYBack,0,0,0,true);
					if in.togglepedestal
						hide(anim, "ped1")
						%editBody(anim, "ped1", -10, -50, 0, 0, 0, true);
					end
				elseif onlyFront
					show(anim, "ballF");
					hide(anim, "ballB");
					editBody(anim, "ballF", startXFront, startYFront, 0, 0, 0, true);
					if in.togglepedestal
						hide(anim, "ped2");
						%editBody(anim, "ped2", 10, -50, 0, 0, 0, true);
					end
				end
			case 'coaction'
				rewardNow = true;
				splitScreen = true;
				show(dwallF); show(dwallB);
				show(anim, "ballF");
				show(anim, "ballB");
				editBody(anim, "ballF", startXFront, startYFront, 0, 0, 0, true);
				editBody(anim, "ballB", startXBack, startYBack, 0, 0, 0, true);
			case 'cooperation'
				rewardNow = false;
				splitScreen = false;
				hide(dwallF); hide(dwallB);
				show(anim, "ballF");
				hide(anim, "ballB");
				editBody(anim, "ballF", startXFront, startYFront, 0, 0, 0, true);
				editBody(anim, "ballB", startXBack, startYBack, 0, 0, 0, true);
				if in.togglepedestal
					show(anim, "ped1");
					hide(anim, "ped2");
				end
			case 'cooperationtime'
				rewardNow = false;
				splitScreen = true;
				show(dwallF); show(dwallB);
				show(anim, "ballF");
				show(anim, "ballB");
				editBody(anim, "ballF", startXFront, startYFront, 0, 0, 0, true);
				editBody(anim, "ballB", startXBack, startYBack, 0, 0, 0, true);
			case 'competition'
				rewardNow = true;
				splitScreen = true;
				show(dwallF); show(dwallB);
				show(anim, "ballF");
				show(anim, "ballB");
				editBody(anim, "ballF", startXFront, startYFront, 0, 0, 0, true);
				editBody(anim, "ballB", startXBack, startYBack, 0, 0, 0, true);
		end
		
		ballF.alphaOut = 1; ballB.alphaOut = 1;
		update(ballF);
		update(ballB);
		update(walls);

		try ballFbody.setGravityScale(1); end
		try ballBbody.setGravityScale(1); end
		
		%=== Update touchManager window with ball positions
		tMF.window.X = ballF.xFinalD;
		tMF.window.Y = ballF.yFinalD;
		tMB.window.X = ballB.xFinalD;
		tMB.window.Y = ballB.yFinalD;

		%=== Initialise Trial Variables
		coopPhase = 1; % there are two phases, 1 is monkeyA and 2 is monkeyB
		coopTimer = NaN; % for cooperationTime
		timerF = NaN; timerB = NaN;
		xy = []; tx = []; ty = []; iv = round(sv.fps/5);
		nowX = NaN; nowY = NaN;
		collF = false; otherBodyF = [];
		collB = false; otherBodyB = [];
		correct = false; correctF = false; correctB = false;
		countDownF = 20; countDownB = 20;
		correctCollideF = false;
		incorrectCollideF = false;
		correctCollideB = false;
		incorrectCollideB = false;
		stepF = false;
		stepB = false;
		didRewardFront = false;
		didRewardBack = false;

		%=== Other Prep
		drawBackground(s, s.backgroundColour);
		flush(tMF); flush(tMB); % flush touch managers

		%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
		%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%RUN OUR TRIAL
		%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
		draw(walls);
		vbl = flip(s); tStart = vbl;
		io.sendStrobe(1);
		switch (in.task)
			case 'control'
				doControl();
				if correctF || correctB; correct = true; end
			case 'coaction'
				doCoaction();
				if correctF || correctB; correct = true; end
			case 'cooperation'
				doCooperation();
				if correctF && correctB; correct = true; end
			case 'cooperationtime'
				doCooperationTime();
				if correctF && correctB; correct = true; end
			case 'competition'
				doCompetition();
				if (correctF && ~correctB) || (correctB && ~correctF); correct = true; end
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
	try close(io); end
	try close(s); end
	try close(tMF); end %#ok<*TRYNC>
	try close(tMB); end %#ok<*TRYNC>
	try reset(ballF); end
	try reset(ballB); end
	try reset(walls); end
	%if in.debug; clear Screen; end

	fprintf('\n\n≣≣≣≣⊱ DATA saving to %s\n', fileName);
	save(fileName,'results','in');

	%plot(in.axis1, results.anidata(end).x,results.anidata(end).y,'-');
	%xlabel(in.axis1,'X Position');
	%ylabel(in.axis1, 'Y Position');
	%plot(in.axis2, results.N, results.correct,'.-');
	%ylim(in.axis2,[-0.1 1.1]);

catch ERR
	getReport(ERR);
	Priority(0); ShowCursor;
	RestrictKeysForKbCheck([]);
	try io.close; end
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
	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	function doControl()
	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
		while ~correct && vbl < tStart + in.trialtime
			if KbCheck; break; end
			stepF = false; stepB = false;
			if onlyFront && (~incorrectCollideF && ~correctCollideF)
				[~, stepF] = processTouch(tMF, ballF, ballFbody, ballFidx); 
				if stepF; doStep(); end
				[collF, otherBodyF] = isCollision(anim, ballFbody); % check collisions
				checkWallsFront();
			elseif onlyBack && (~incorrectCollideB && ~correctCollideB)
				[~, stepB] = processTouch(tMB, ballB, ballBbody, ballBidx);
				if stepB; doStep(); end
				[collB, otherBodyB] = isCollision(anim, ballBbody); % check collisions
				checkWallsBack();
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
			if in.debug; drawGrid(s); drawScreenCenter(s); end
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
					correct = false; break
				end
			end 
		end
	end

	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	function doCoaction()
	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
		while ~correct && (vbl < tStart + in.trialtime)
			if KbCheck; break; end
			stepF = false; stepB = false;
			[~, stepF] = processTouch(tMF, ballF, ballFbody, ballFidx);
			[~, stepB] = processTouch(tMB, ballB, ballBbody, ballBidx);
			[collF, otherBodyF] = isCollision(anim, ballFbody); % check collisions
			[collB, otherBodyB] = isCollision(anim, ballBbody); % check collisions
			if stepF || stepB; doStep(); end
			checkDivider();
			updateDivider();
			draw(ballF); draw(ballB); 
			draw(walls);
			if in.debug; drawGrid(s); drawScreenCenter(s); end
			vbl = flip(s, vbl + sv.halfifi);
			% save all animation data for each trial, we can use this to "play
			% back" the action performed by the monkey
			updateFrame();
			if countDownF == 0 || countDownB == 0
				if correctCollideF
					correctF = true;
				end
				if correctCollideB
					correctB = true;
				end
				if correctF && correctB
					break
				end
				if incorrectCollideF || incorrectCollideB
					break
				end
			end 
		end
	end

	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	function doCooperation()
	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
		while ~correct && (vbl < tStart + in.trialtime)
			if KbCheck; break; end
			if coopPhase == 1
				if ~incorrectCollideF && ~correctCollideF
					[~, stepF] = processTouch(tMF, ballF, ballFbody, ballFidx);
					if stepF; doStep(); end
					[collF, otherBodyF] = isCollision(anim, ballFbody); % check collisions
					checkWallsFront();
				end 
			elseif coopPhase == 2
				if ~incorrectCollideB && ~correctCollideB
					[~, stepB] = processTouch(tMB, ballB, ballBbody, ballBidx);
					if stepB; doStep(); end
					[collB, otherBodyB] = isCollision(anim, ballBbody); % check collisions
					checkWallsBack();
				end 
			end
			
			% logic for switching phase
			if coopPhase == 1 && correctCollideF && countDownF < 1 && ~correctF
				fprintf('\n≣≣≣≣⊱ FRONT CORRECT @ %.2f\n', vbl - tStart);
				correctF = true; 
				coopPhase = 2;
				if in.togglepedestal
					show(anim, "ped2");
					hide(anim, "ped1");
				end
				hide(anim, "ballF");
				show(anim, "ballB");
				editBody(anim, "ballB", startXBack, startYBack, 0, 0, 0, true);
			end
			if coopPhase == 2 && correctCollideB && countDownB < 1 && ~correctB
				fprintf('\n≣≣≣≣⊱ BACK CORRECT @ %.2f\n', vbl - tStart);
				correctB = true; correct = true; break
			end
			updateWalls();
			if coopPhase == 1
				draw(ballF); 
			else
				draw(ballB); 
			end
			draw(walls);
			if in.debug; drawGrid(s); drawScreenCenter(s); end
			vbl = flip(s, vbl + sv.halfifi);

			% save all animation data for each trial, we can use this to "play
			% back" the action performed by the subject
			updateFrame();

			
		end
	end

	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	function doCooperationTime()
	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
		while ~correct && vbl < tStart + in.trialtime
			if KbCheck; break; end
			[~, stepF] = processTouch(tMF, ballF, ballFbody, ballFidx);
			[~, stepB] = processTouch(tMB, ballB, ballBbody, ballBidx);
			if stepF || stepB; doStep(); end 
			[collF, otherBodyF] = isCollision(anim, ballFbody); % check collisions
			[collB, otherBodyB] = isCollision(anim, ballBbody); % check collisions
			checkDivider();
			t = NaN; tboth = false;
			if ~isnan(timerF) && ~isnan(timerB)
				t = abs(timerF-timerB);
				tboth = true;
			elseif ~isnan(timerF) 
				t = abs(timerF-GetSecs);
			elseif ~isnan(timerB) 
				t = abs(timerB-GetSecs);
			end
			if tboth && t <= in.cooptime
				coopTimer = true;
				fprintf('\n≣≣≣≣⊱ TIMER PASS %.2f\n',t);
			elseif ~tboth && ~isnan(t) && t >= in.cooptime
				coopTimer = false;
				fprintf('\n≣≣≣≣⊱ TIMER FAIL %.2f\n',t);
			end
			updateDivider();
			draw(ballF); draw(ballB); 
			draw(walls);
			if in.debug; drawGrid(s); drawScreenCenter(s); end
			vbl = flip(s, vbl + sv.halfifi);
			% save all animation data for each trial, we can use this to "play
			% back" the action performed by the monkey
			updateFrame();
			if coopTimer == true
				correctF = true;
				correctB = true;
				correct = true;
				break
			elseif coopTimer == false
				correctF = false;
				correctB = false;
				correct = false;
				break
			end
			if incorrectCollideF || incorrectCollideB
				break
			end
		end
	end

	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	function doCompetition()
	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
		while ~correct && vbl < tStart + in.trialtime
			if KbCheck; break; end
			[~, stepF] = processTouch(tMF, ballF, ballFbody, ballFidx);
			[~, stepB] = processTouch(tMB, ballB, ballBbody, ballBidx);
			if stepF || stepB; doStep(); end 
			[collF, otherBodyF] = isCollision(anim, ballFbody); % check collisions
			[collB, otherBodyB] = isCollision(anim, ballBbody); % check collisions
			checkDivider();
			t = vbl - tStart;
			if incorrectCollideF && correctCollideB
				fprintf('\n≣≣≣≣⊱ BACK WINS IN %.2f secs\n',t);
				hide(ballF)
				anim.setSensorState('ballF',true);
			end
			if incorrectCollideB && correctCollideF
				fprintf('\n≣≣≣≣⊱ FRONT WINS IN %.2f secs\n',t);
				hide(ballB); 
				anim.setSensorState('ballB',true);
			end
			updateDivider();
			draw(ballF); 
			draw(ballB); 
			draw(walls);
			if in.debug; drawGrid(s); drawScreenCenter(s); end
			vbl = flip(s, vbl + sv.halfifi);
			% save all animation data for each trial, we can use this to "play
			% back" the action performed by the monkey
			updateFrame();
			if countDownF == 0 || countDownB == 0
				fprintf('\n≣≣≣≣⊱ FINISH @ %.2f secs\n',t);
				if correctCollideF
					correct = true; correctF = true; correctB = false; break
				end
				if correctCollideB
					correct = true; correctB = true; correctF = false; break
				end
				if incorrectCollideF || incorrectCollideB
					break
				end
			end 
		end
	end

	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	function [inTouch, step] = processTouch(tM, stim, body, idx) %process touch window
	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
		if ~exist('idx','var') || isempty(idx); idx = 1; end
		inTouch = false; step = false;
		if tM.eventAvail % check we have touch event[s]
			tM.window.X = stim.xFinalD;
			tM.window.Y = stim.yFinalD;
			[tch, ~, wasEvent] = checkTouchWindows(tM); % check we are in touch window
			if ~wasEvent; return; end
			if tch == true; inTouch = true; end
			evt = tM.event;
			nowX = tM.x; nowY = tM.y;
			if inTouch && evt.Type == 4 % this is a RELEASE event
				if in.verbose; fprintf('≣≣≣≣⊱ processTouch@%s:RELEASE X: %.1f Y: %.1f \n',stim.name,nowX,nowY); end
				if length(tx) >= 3 %collected enough samples
					ln = length(tx); if ln > iv; ln = iv; end
					xy = [tx(end-(ln-1):end)' ty(end-(ln-1):end)'];
					vx = mean(diff(xy(:,1))) * ln * in.sensitivity;
					vy = mean(diff(xy(:,2))) * ln * in.sensitivity;
					av = vx / 2;
					x = xy(end,1);
					y = xy(end,2);
					if in.verbose
						fprintf(['≣≣≣≣⊱ processtouch@%s:VELOCITY tchX:%.1f tchY:%.1f \nX%i: stimX:%.1f evtX:%.1f animX:%.1f n:%.1f v:%.1f\n' ...
							'Y: stimY:%.1f evtY:%.1f animY:%.1f n:%.1f v:%.1f -- A: %.1f\n'], ...
						stim.name, nowX, nowY, ln, stim.xFinal, evt.MappedX, anim.x(idx), x, vx, ...
						stim.yFinal, evt.MappedY, anim.y(idx), y, vy, av); 
					end
					anim.editBody(body,x,y,vx,vy,av);
				end
				step = true;
				xy = []; tx = []; ty = []; inTouch = false;
			elseif inTouch && ~isempty(evt) && evt.Type > 0 && evt.Type < 4
				checkLimits(limits(1:4), stim, evt);
				tx = [tx nowX];
				ty = [ty nowY];
				anim.editBody(body, nowX, nowY);
				if in.verbose; fprintf('≣≣≣≣⊱ processTouch@%s:TOUCH X: %.1f Y: %.1f \n',...
						stim.name, nowX,nowY); 
				end
			else
				step = true;
			end
		else % no touch events are available, just run the physics engine
			step = true;
		end
	end

	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	function doStep() % step the physics world
	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
		step(anim);
		xF = anim.x(1); yF = anim.y(1);
		if ~isscalar(anim.x)
			xB = anim.x(2); yB = anim.y(2);
		else
			xB = []; yB = [];
		end
		if stepF
			ballF.updateXY(xF, yF, true);
			a = anim.angularVelocity(ballFidx);
			ballF.angleOut = ballF.angleOut + (rad2deg(a) * anim.timeDelta);
		end
		if stepB && ~isempty(xB)
			ballB.updateXY(xB, yB, true);
			a = anim.angularVelocity(ballBidx);
			ballB.angleOut = ballB.angleOut + (rad2deg(a) * anim.timeDelta);
		end
	end

	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	function checkLimits(inlimits,inball,inevt)
	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
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
		elseif ~isempty(newY)
			nowY = newY;
			inball.updateXY(inevt.MappedX, pxY, false);
		elseif ~isempty(newX)
			nowX = newX;
			inball.updateXY(pxX, inevt.MappedY, false);
		else
			inball.updateXY(inevt.MappedX, inevt.MappedY, false);
		end
	end
	
	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	function checkWallsFront()
	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
		if collF && otherBodyF.hashCode == rwhash
			correctCollideF = true; stepF = true;
		elseif collF && otherBodyF.hashCode == lwhash
			incorrectCollideF = true; stepF = true;
		end
	end

	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	function checkWallsBack()
	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
		if collB && otherBodyB.hashCode == lwhash
			correctCollideB = true; stepB = true;
		elseif collB && otherBodyB.hashCode == rwhash			
			incorrectCollideB = true; stepB = true;
		end
	end

	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	function checkDivider()
	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
		if collF && ~incorrectCollideF && ~isempty(otherBodyF) && otherBodyF.hashCode == dwfhash
			timerF = GetSecs;
			if matches(in.task,'competition')
				correctCollideF = true;
				incorrectCollideB = true; 
			else
				correctCollideF = true;
			end
		end
		if collB && ~incorrectCollideB && ~isempty(otherBodyB) && otherBodyB.hashCode == dwbhash
			timerB = GetSecs;
			if matches(in.task,'competition')
				correctCollideB = true;
				incorrectCollideF = true; 
			else
				correctCollideB = true;
			end
		end
	end

	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	function updateWalls()
	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
		if onlyFront || bothSides
			if correctCollideF
				walls{3}.colourOut = [0.3 0.7 0 1]; walls{3}.refreshTexture();
				%ballFbody.setGravityScale(100);
				ballF.alphaOut = ballF.alphaOut - 0.05;
				if ballF.alphaOut < 0; ballF.alphaOut = 0; end
				countDownF = countDownF - 1;
				if countDownF == 0
					walls{3}.colourOut = [in.wallColour]; walls{3}.refreshTexture();
					hide(ballF); draw(walls);
					flip(s);
				end
				if rewardNow && ~didRewardFront
					beep(aM, 3000,0.1,0.5); 
					giveReward(rwdFront); 
					rewardGiven = true; 
					didRewardFront = true;
					if doIO; io.sendStrobe(254); end
				end
			elseif incorrectCollideF
				walls{1}.colourOut = [0.6 0.2 0.2]; walls{1}.refreshTexture();
				%ballFbody.setGravityScale(100);
				ballF.alphaOut = ballF.alphaOut - 0.05;
				if ballF.alphaOut < 0; ballF.alphaOut = 0; end
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
				%ballBbody.setGravityScale(100);
				countDownB = countDownB - 1;
				ballB.alphaOut = ballB.alphaOut - 0.05;
				if ballB.alphaOut < 0; ballB.alphaOut = 0; end
				if countDownB == 0
					walls{1}.colourOut = [in.wallColour]; walls{1}.refreshTexture();
					hide(ballB); draw(walls);
					flip(s); 
				end
				if rewardNow && ~didRewardBack
					beep(aM, 2500,0.1,0.5); 
					giveReward(rwdBack); 
					rewardGiven = true; 
					didRewardBack = true;
					if doIO; io.sendStrobe(254); end
				end
			elseif incorrectCollideB
				walls{3}.colourOut = [0.6 0.2 0.2]; walls{3}.refreshTexture();
				%ballBbody.setGravityScale(100);
				ballB.alphaOut = ballB.alphaOut - 0.05;
				if ballB.alphaOut < 0; ballB.alphaOut = 0; end
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
	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
		if onlyFront || bothSides
			if correctCollideF
				if matches(in.task,'competition'); hide(ballB); end
				dwallF.colourOut = [0.3 0.7 0 1]; dwallF.refreshTexture();
				ballF.alphaOut = ballF.alphaOut - 0.05;
				if ballF.alphaOut < 0; ballF.alphaOut = 0; end
				countDownF = countDownF - 1;
				if countDownF == 0
					dwallF.colourOut = [in.wallColour]; dwallF.refreshTexture();
					hide(ballF);
				end
				if rewardNow && ~didRewardFront
					beep(aM, 3000,0.1,0.5); 
					giveReward(rwdFront); 
					rewardGiven = true; 
					didRewardFront = true;
					if doIO; io.sendStrobe(254); end
				end
			end
		end
		if onlyBack || bothSides
			if correctCollideB
				if matches(in.task,'competition'); hide(ballF); end
				dwallB.colourOut = [0.3 0.7 0 1]; dwallB.refreshTexture();
				ballB.alphaOut = ballB.alphaOut - 0.05;
				if ballB.alphaOut < 0; ballB.alphaOut = 0; end
				countDownB = countDownB - 1;
				if countDownB == 0
					dwallB.colourOut = [in.wallColour]; dwallB.refreshTexture();
					hide(ballB); 
				end
				if rewardNow && ~didRewardBack 
					beep(aM, 2500,0.1,0.5); 
					giveReward(rwdBack); 
					rewardGiven = true; 
					didRewardBack = true;
					if doIO; io.sendStrobe(254); end
				end
			end
		end
	end

	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	function updateFrame()
	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
		results.anidata(jj).t =  [results.anidata(jj).t, anim.timeStep];
		results.anidata(jj).x =  [results.anidata(jj).x, anim.x(1)];
		results.anidata(jj).y =  [results.anidata(jj).y, anim.y(1)];
		if length(anim.x) > 1
			results.anidata(jj).x2 =  [results.anidata(jj).x2, anim.x(2)];
			results.anidata(jj).y2 =  [results.anidata(jj).y2, anim.y(2)];
		end
		results.anidata(jj).dx = [results.anidata(jj).dx, anim.dX];
		results.anidata(jj).dy = [results.anidata(jj).dy, anim.dY];
		results.anidata(jj).ke = [results.anidata(jj).ke, anim.kineticEnergy];
		results.anidata(jj).pe = [results.anidata(jj).pe, anim.potentialEnergy];
	end

	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	function updateTrial()
	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
		
		if doIO; io.sendStrobe(255); end
		
		fprintf('≣≣≣≣⊱ Final Positions: BF X %.1f Y %.1f BB X %.1f Y %.1f\n',anim.x(1),anim.y(1),anim.x(2),anim.y(2));
		results.coopPhase = [results.coopPhase coopPhase];
		results.coopTimer = [results.coopTimer coopTimer];
		results.timerF = [results.timerF timerF];
		results.timerB = [results.timerB timerB];
		results.correctCollideF = false;
		results.incorrectCollideF = false;
		results.correctCollideB = false;
		results.incorrectCollideB = false;
		results.N = [results.N jj];
		results.correct = [results.correct correct];
		results.correctF = [results.correctF correctF];
		results.correctB = [results.correctB correctB];
		results.wallPos = [results.wallPos 1];
		results.RT = [results.RT (tStart - GetSecs)];

		reset(tMF); reset(tMB);

		dwallF.colourOut = [in.wallColour]; dwallF.refreshTexture();
		dwallB.colourOut = [in.wallColour]; dwallB.refreshTexture();
	
		if correct
			disp('≣≣≣≣⊱ CORRECT');
			if doIO; io.sendStrobe(250); end
			if correctF
				nCorrectF = nCorrectF + 1;
				if ~rewardNow && ~didRewardFront; beep(aM, 3000,0.1,0.5); giveReward(rwdFront);end
				if splitScreen
					drawRect(s, frontHalf,[0.3 0.6 0.3]);
					if matches(in.task,'competition') || ~correctB
						drawRect(s, backHalf,[0.6 0.2 0.2]);
					end
				else
					drawBackground(s, [0.3 0.6 0.3]);
				end
			end
			if correctB
				nCorrectB= nCorrectB + 1;
				if ~rewardNow && ~didRewardBack; beep(aM, 2500,0.1,0.5); giveReward(rwdBack);end
				if splitScreen
					drawRect(s, backHalf,[0.3 0.6 0.3]);
					if matches(in.task,'competition') || ~correctB
						drawRect(s, frontHalf,[0.6 0.2 0.2]);
					end
				else
					drawBackground(s, [0.3 0.6 0.3]);
				end
			end
			draw(walls);
			flip(s);
			WaitSecs('Yieldsecs',0.1);
			drawBackground(s, s.backgroundColour); draw(walls); flip(s);
			WaitSecs('Yieldsecs',correctITI);
		else
			disp('≣≣≣≣⊱ INCORRECT');
			if doIO; io.sendStrobe(251); end
			if splitScreen && ~correctF && ~correctB
				drawRect(s, frontHalf,[0.6 0.2 0.2]);
				drawRect(s, backHalf,[0.6 0.2 0.2]);
			elseif splitScreen && ~correctF
				drawRect(s, frontHalf,[0.6 0.2 0.2]);
			elseif splitScreen && ~correctB
				drawRect(s, backHalf,[0.6 0.2 0.2]);
			else
				drawBackground(s, [0.6 0.2 0.2]);
			end
			draw(walls); flip(s);
			WaitSecs('Yieldsecs',0.1);
			drawBackground(s, s.backgroundColour); draw(walls); flip(s); 
			WaitSecs('Yieldsecs',incorrectITI);
		end

		drawBackground(s, s.backgroundColour); draw(walls); flip(s); 
	
		plot(in.axis1, results.anidata(end).x,results.anidata(end).y,'go-');
		if isfield(results.anidata,'x2') && ~isempty(results.anidata(end).x2)
			hold(in.axis1, "on");
			plot(in.axis1, results.anidata(end).x2,results.anidata(end).y2,'ro-');
			legend(in.axis1, {'Front', 'Back'}, 'Location', 'northwest');
		end
		xlabel(in.axis1,'X Position');
		ylabel(in.axis1, 'Y Position');
		hold(in.axis1,'off');
		ax1 = [sv.leftInDegrees+in.leftW sv.rightInDegrees-in.rightW sv.topInDegrees+in.ceiling sv.bottomInDegrees-in.floor];
		
		axis(in.axis1, ax1, 'ij');
		hold(in.axis2,'on');
		plot(in.axis2, results.N, results.correct,'bo-');
		plot(in.axis2, results.N, results.correctF,'g.-');
		plot(in.axis2, results.N, results.correctB,'r.-');
		legend(in.axis2, {'All', 'Front', 'Back'}, 'Location', 'northwest');
		ylim(in.axis2,[-0.1 1.1])
		yticks(in.axis2,[0 1]);
		yticklabels(in.axis2, {'no', 'yes'});
		hold(in.axis2,'off');
		pCorrect = (sum(results.correct) / jj)*100;
		title(in.axis2,['% Correct: ' num2str(pCorrect) '%'])
		xlabel(in.axis2,'Trial #');
		ylabel(in.axis2, 'Correct');
		drawnow;
	
	end
	
	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	function array = push(array, value)
	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
		array = [array value];
	end

end