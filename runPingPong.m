function runPingPong(in)

try 
	s = screenManager;
	s.backgroundColour = [0 0 0];
	if max(Screen('Screens')) == 0; s.windowed = [0 0 1000 800]; s.specialFlags = 0; end
	sv = open(s);
	
	%==============================================Arduino initialization
	rwd_front = arduinoManager('port',in.arduinoa,'shield','new');
	if in.dummy; rwd_front.silentMode = true; end
	rwd_front.open;

	rwd_back = arduinoManager('port',in.arduinob,'shield','new');
	if in.dummy; rwd_back.silentMode = true; end
	rwd_back.open;
	
	%==============================================Audio Manager
	if ~exist('aM','var') || isempty(aM) || ~isa(aM,'audioManager')
		aM = audioManager;
	end
	aM.silentMode = false;
	if ~aM.isSetup;	aM.setup; end
	
	%==============================================STIMULUS
	ball = imageStimulus('name','ball');
	ball.filePath = in.image;
	ball.xPosition = in.startA;
	ball.yPosition = sv.bottomInDegrees - in.floor - in.ballSize - 0.2;
	ball.angle = 0;
	ball.speed = 0;
	ball.size = in.ballSize;
	radius = ball.size/2;
	startx = ball.xPosition;
	starty = ball.yPosition;
	setup(ball, s); show(ball);

	ped1 = imageStimulus('name','ped1');
	ped1.filePath = 'pedestal.png';
	ped1.size = 4;
	ped1.xPosition = in.startA;
	ped1.yPosition = ball.yPosition+2;
	ped2 = clone(ped1);
	ped2.name = 'ped2';
	ped2.xPosition = in.startB;
	peds = metaStimulus('stimuli',{ped1,ped2});
	setup(peds, s); show(peds);

	%===============================================ANIMATION MANAGER
	anim = animationManager('verbose', in.verbose);
	anim.timeDelta = sv.ifi;
	anim.rigidParams.linearDamping = in.linearD;
	walls = anim.addScreenBoundaries(sv,[in.leftW in.ceiling in.rightW in.floor]);
	edit(walls,1:4,'colour',[0.25 1 1 1]);
	setup(walls, s); show(walls);
	[lwb, ~, lwbidx] = anim.getBody('leftwall');
	[clb, ~, clbidx] = anim.getBody('ceiling');
	[rwb, ~, rwbidx] = anim.getBody('rightwall');
	[flb, ~, flbidx] = anim.getBody('floor');
	anim.addBody(ped1,'Rectangle','infinite');
	anim.addBody(ped2,'Rectangle','infinite');
	anim.addBody(ball,'Circle','normal');
	[ballb, ballidx] = anim.getBody('ball');
	setup(anim, s);
	
	%===============================================TOUCH
	tM = touchManager('isDummy',in.dummy,'verbose',in.verbose);
	tM.window.radius = radius;
	tM.window.X = startx;
	tM.window.Y = starty;
	setup(tM, s);
	createQueue(tM);
	start(tM);
	
	%===============================================setup some other parameters
	nTrials = 500;
	moveWallAfterNCorrectTrials = 3;
	nCorrect = 0;
	RestrictKeysForKbCheck(KbName('ESCAPE'));
	[pth, sID, dID] = getALF(s, [in.subjecta '-' in.subjectb],'pp','cogp',true);
	fileName = [pth 'PingPong-' dID '-.mat'];

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
		fprintf('--->>> Trial: %i - Wall: %.1f\n', jj,1);
		ball.xPositionOut = startx;
		ball.yPositionOut = starty;
		ball.update;
		ballb.setGravityScale(1);
		tM.window.X = ball.xFinalD;
		tM.window.Y = ball.yFinalD;
		
		% the animator needs to be updated to the ball on each trial
		update(anim);
		
		xy = []; tx = []; ty = []; iv = round(sv.fps/5);
		correct = false;
		countDown = 60;
		correctCollide = false;
		incorrectCollide = false;
		inTouch = false;
		drawBackground(s, s.backgroundColour);
		flush(tM);
		vbl = flip(s); tStart = vbl;

		while ~correct && vbl < tStart + 60
			if KbCheck; break; end
			if tM.eventAvail % check we have touch event[s]
				tM.window.X = ball.xFinalD;
				tM.window.Y = ball.yFinalD;
				tch = checkTouchWindows(tM); % check we are in touch window
				if tch; inTouch = true; end
				e = tM.event;
				if e.Type == 4 % this is a RELEASE event
					if tM.verbose; fprintf('RELEASE X: %.1f Y: %.1f \n',e.X,e.Y); end
					xy = []; tx = []; ty = []; inTouch = false;
				end
				if inTouch && ~isempty(e) && e.Type > 1 && e.Type < 4
					if tM.y+radius > (walls{1}.yPosition) % make sure we don't move below the floor
						ball.updateXY(e.MappedX, toPixels(s,walls{1}.yPosition-radius,'y'), false);
					else
						ball.updateXY(e.MappedX, e.MappedY, false);
					end
					tx = [tx tM.x];
					ty = [ty tM.y];
					if length(tx) >= iv %collect enough samples
						xy = [tx(end-(iv-1):end)' ty(end-(iv-1):end)'];
						vx = mean(diff(xy(:,1))) * iv * in.sensitivity;
						vy = mean(diff(xy(:,2))) * iv * in.sensitivity;
						av = vx / 2;
						x = xy(end,1);
						y = xy(end,2);
						if tM.verbose; fprintf('UPDATE X: stim:%.1f evt:%.1f anim:%.1f n:%.1f v:%.1f Y: stim:%.1f evt:%.1f anim:%.1f n:%.1f v:%.1f A: %.1f\n', ...
							ball.xFinal, e.MappedX, anim.x, x, vx, ball.yFinal, e.MappedY, anim.y, y, vy, av); end
						anim.editBody(ballb,x,y,vx,vy,av);
					else
						anim.editBody(ballb,tM.x,tM.y);
					end
				else
					step(anim);
					ball.updateXY(anim.x, anim.y, true);
					a = anim.angularVelocity(ballidx);
					ball.angleOut = ball.angleOut + (rad2deg(a) * anim.timeDelta);
				end
			else
				step(anim);
				ball.updateXY(anim.x, anim.y, true);
				a = anim.angularVelocity(ballidx);
				ball.angleOut = ball.angleOut + (rad2deg(a) * anim.timeDelta);
			end
			[coll, otherBody] = isCollision(anim, ballb);
			if coll && otherBody.hashCode == anim.bodies(rwbidx).hash
				correctCollide = true;
			elseif coll && otherBody.hashCode == anim.bodies(lwbidx).hash
				incorrectCollide = true;
			end
			if correctCollide
				%ballb.setGravityScale(0.1);
				countDown = countDown - 1;
				if countDown == 0
					correct = true;
				end
			elseif incorrectCollide
				%ballb.setGravityScale(0.1);
				countDown = countDown - 1;
				if countDown == 0
					break;
				end
			end
			draw(peds);
			draw(ball);
			draw(walls);
			drawGrid(s);
			vbl = flip(s, vbl + sv.halfifi);
			% save all animation data for each trial, we can use this to "play
			% back" the action performed by the monkey
			updateFrame();
		end

		if KbCheck; break; end

		if strcmpi(in.task,'control')
			updateTrial();
		end
		
	end

	Priority(0);
	RestrictKeysForKbCheck([]);
	disp(['--->>> DATA saving to ' fileName]);
	save(fileName,'results');
	try close(tM); end %#ok<*TRYNC>
	try reset(ball); end
	try reset(walls); end
	try reset(peds); end
	try close(s); end

	plot(in.axis1, results.anidata(end).x,results.anidata(end).y,'-');
	xlabel(in.axis1,'X Position');
	ylabel(in.axis1, 'Y Position');
	plot(in.axis2, results.N, results.correct,'.-');
	ylim(in.axis2,[-0.1 1.1]);

	figure;
	tiledlayout(3,1);
	for jj = 1:length(results.anidata)
		nexttile(1);
		hold on
		plot(results.anidata(jj).x,results.anidata(jj).y);
		nexttile(2);
		hold on;
		plot(results.anidata(jj).t,results.anidata(jj).ke);
		nexttile(2);
		hold on;
		plot(results.anidata(jj).t,results.anidata(jj).pe);
	end
	title(fileName)
	nexttile(1);
	xlabel('X Position');
	ylabel('Y Position');
	axis equal; axis ij
	box on; grid on;
	nexttile(2);
	xlabel('Time');
	ylabel('Kinetic Energy');
	box on; grid on;
	nexttile(3);
	xlabel('Time');
	ylabel('Potential Energy');
	box on; grid on;

catch ERR
	getReport(ERR);
	Priority(0);
	RestrictKeysForKbCheck([]);
	try anim.reset; end
	try tM.close; end
	try ball.reset; end
	try s.close; end
	try sca; end
	rethrow(ERR);
end

	function updateFrame()
		results.anidata(jj).t =  [results.anidata(jj).t, anim.timeStep];
		results.anidata(jj).x =  [results.anidata(jj).x, anim.x];
		results.anidata(jj).y =  [results.anidata(jj).y, anim.y];
		results.anidata(jj).dx = [results.anidata(jj).dx, anim.dX];
		results.anidata(jj).dy = [results.anidata(jj).dy, anim.dY];
		results.anidata(jj).ke = [results.anidata(jj).ke, anim.kineticEnergy];
		results.anidata(jj).pe = [results.anidata(jj).pe, anim.potentialEnergy];
	end

	function updateTrial()
		results.N = [results.N jj];
		results.correct = [results.correct correct];
		results.wallPos = [results.wallPos 1];
		results.RT = [results.RT (tStart - GetSecs)];
	
		if correct
			nCorrect = nCorrect + 1;
			drawBackground(s, [0.3 0.6 0.3]);
			flip(s);
			giveReward(rwd_front);
			beep(aM, 3000,0.1,0.1);
			disp('--->>> CORRECT');
			WaitSecs('Yieldsecs',2);
		else
			disp('--->>> FAIL');
			beep(aM, 300,0.5,0.5);
			drawBackground(s, [0.6 0.3 0.3]);
			flip(s);
			WaitSecs('Yieldsecs',3);
		end
	
		plot(in.axis1, results.anidata(end).x,results.anidata(end).y,'-');
		xlabel(in.axis1,'X Position');
		ylabel(in.axis1, 'Y Position');
		axis(in.axis1,'ij');
		plot(in.axis2, results.N, results.correct,'.-');
		xlabel(in.axis2,'Trial');
		ylabel(in.axis2, 'Correct');
		drawnow limitrate nocallbacks
	
	end
	
	function array = push(array, value)
		array = [array value];
	end

end