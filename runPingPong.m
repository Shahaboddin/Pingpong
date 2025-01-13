function runPingPong(in)

if ~exist('in','var'); error('Need to run this from the GUI!'); end

try 
	s = screenManager;
	s.backgroundColour = [0 0 0];
	if max(Screen('Screens')) == 0; s.windowed = [0 0 1000 800]; s.specialFlags = 0; end
	sv = open(s);
	
	%==============================================Arduino initialization
	rwd_front = arduinoManager('port',in.arduinoa,'shield','new');
	if isempty(in.arduinoa); rwd_front.silentMode = true; end
	rwd_front.open;

	rwd_back = arduinoManager('port',in.arduinob,'shield','new');
	if isempty(in.arduinob); rwd_back.silentMode = true; end
	rwd_back.open;
	
	%==============================================Audio Manager
	if ~exist('aM','var') || isempty(aM) || ~isa(aM,'audioManager')
		aM = audioManager;
	end
	aM.silentMode = false;
	if ~aM.isSetup;	aM.setup; end
	
	%==============================================BALL and PEDESTALS
	ped1 = barStimulus('name','ped1');
	ped1.colour = in.wallColour;
	ped1.alpha = 0.8;
	ped1.type = 'solid';
	ped1.scaleTexture = 5;
	ped1.barWidth = 4;
	ped1.barHeight = 3;
	ped1.xPosition = in.startA;
	ped1.yPosition = sv.bottomInDegrees - in.floor;
	ped2 = clone(ped1);
	ped2.name = 'ped2';
	ped2.xPosition = in.startB;

	ball = imageStimulus('name','ball');
	ball.filePath = in.image;
	ball.xPosition = in.startA;
	ball.yPosition = ped1.yPosition - in.ballSize;
	ball.angle = 0;
	ball.speed = 0;
	ball.size = in.ballSize;
	radius = ball.size/2;
	startx = ball.xPosition;
	starty = ball.yPosition;
	setup(ball, s); show(ball);
	
	%===============================================ANIMATION MANAGER
	anim = animationManager('verbose', in.verbose);
	anim.timeDelta = sv.ifi/2;
	anim.rigidParams.linearDamping = in.linearD;
	% this creates 4 walls, returns a metaStimulus we can use to draw the walls
	% visually
	walls = anim.addScreenBoundaries(sv,[in.leftW in.ceiling in.rightW in.floor]);
	% include our pedestals into this metaStimulus
	walls{walls.n+1} = ped1;
	walls{walls.n+1} = ped2;
	% setup metaStimulus
	setup(walls, s); show(walls);
	% get our wall bodies we can use for collision analysis
	[lwb, ~, lwbidx] = anim.getBody('leftwall');
	[clb, ~, clbidx] = anim.getBody('ceiling');
	[rwb, ~, rwbidx] = anim.getBody('rightwall');
	[flb, ~, flbidx] = anim.getBody('floor');
	% add pedestals and ball to physics simulation
	anim.addBody(ped1,'Rectangle','infinite');
	anim.addBody(ped2,'Rectangle','infinite');
	anim.addBody(ball,'Circle','normal');
	% get ball body
	[ballb, ballidx] = anim.getBody('ball');
	% setup our physics world
	setup(anim, s);

	%===============================================DEFINE TOUCH LIMITS
	fLimit = walls{4}.yPosition - (walls{4}.barHeight/2) - radius;
	cLimit = walls{2}.yPosition + (walls{2}.barHeight/2) + radius;
	lLimit = walls{1}.xPosition + (walls{1}.barWidth/2) + radius;
	rLimit = walls{3}.xPosition - (walls{3}.barWidth/2) - radius;
	
	%===============================================TOUCH MANAGER
	tM = touchManager('isDummy',in.dummy,'verbose',in.verbose);
	tM.window.radius = radius; % taken from the ball
	tM.window.X = startx; % lock to the ball position
	tM.window.Y = starty; % lock to the ball position
	setup(tM, s);
	createQueue(tM);
	start(tM);
	
	%===============================================setup some other parameters
	nTrials = 500;
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
				nowX = tM.x; nowY = tM.y;
				if e.Type == 4 % this is a RELEASE event
					if in.verbose; fprintf('>>>RELEASE X: %.1f Y: %.1f \n',nowX,nowY); end
					if length(tx) >= 3 %collect enough samples
						ln = length(tx); if ln > iv; ln = iv; end
						xy = [tx(end-(ln-1):end)' ty(end-(ln-1):end)'];
						vx = mean(diff(xy(:,1))) * ln * in.sensitivity;
						vy = mean(diff(xy(:,2))) * ln * in.sensitivity;
						av = vx / 2;
						x = xy(end,1);
						y = xy(end,2);
						if in.verbose; fprintf('>>>UPDATE X%i: stim:%.1f evt:%.1f anim:%.1f n:%.1f v:%.1f Y: stim:%.1f evt:%.1f anim:%.1f n:%.1f v:%.1f A: %.1f\n', ...
							ln, ball.xFinal, e.MappedX, anim.x, x, vx, ball.yFinal, e.MappedY, anim.y, y, vy, av); end
						anim.editBody(ballb,x,y,vx,vy,av);
					end
					step(anim);
					ball.updateXY(anim.x, anim.y, true);
					a = anim.angularVelocity(ballidx);
					ball.angleOut = ball.angleOut + (rad2deg(a) * anim.timeDelta);
					xy = []; tx = []; ty = []; inTouch = false;
				elseif inTouch && ~isempty(e) && e.Type > 1 && e.Type < 4
					if nowY > fLimit % make sure we don't move below the floor
						nowY = fLimit;
						ball.updateXY(e.MappedX, toPixels(s,fLimit,'y'), false);
					elseif nowY < cLimit
						nowY = cLimit;
						ball.updateXY(e.MappedX, toPixels(s,cLimit,'y'), false);
					elseif nowX < lLimit
						nowX = lLimit;
						ball.updateXY(toPixels(s,lLimit,'x'), e.MappedY, false);
					elseif nowX > rLimit
						nowX = rLimit;
						ball.updateXY(toPixels(s,rLimit,'x'), e.MappedY, false);
					else
						ball.updateXY(e.MappedX, e.MappedY, false);
					end
					tx = [tx nowX];
					ty = [ty nowY];
					anim.editBody(ballb,nowX,nowY);
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
				%ballb.setGravityScale(100);
				countDown = countDown - 1;
				if countDown == 0
					correct = true;
				end
			elseif incorrectCollide
				%ballb.setGravityScale(100);
				countDown = countDown - 1;
				if countDown == 0
					break;
				end
			end
			draw(ball);
			draw(walls);
			drawGrid(s);
			drawScreenCenter(s);
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