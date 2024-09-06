function runPingPong(in)
%==============================================Screen
verbose = true;
ballSize = in.ballSize;
startX1 = in.startA;
startX2 = in.startB;
airResistanceCoeff = in.airR;
elasticityCoeff = in.elasticity;

%===============================================
% this modifies the touch movement > velocity
% higher values means bigger impact
touchSensitivity = in.sensitivity;

try 
	s = screenManager;
	s.backgroundColour = [0 0 0];
	if max(Screen('Screens')) == 0; s.windowed = [0 0 1100 800]; s.specialFlags = 0; end
	sv = open(s);
	
	%==============================================Arduino initialization
	if ~exist('rM','var') || isempty(rM)
		rM = arduinoManager();
	end
	rM.reward.pin = 2;
	rM.reward.time = 300;

	rwd_front = arduinoManager('port',in.arduinoa,'shield','new');
	rwd_front.silentMode = true;
	rwd_front.open;
	
	%==============================================Audio Manager
	if ~exist('aM','var') || isempty(aM) || ~isa(aM,'audioManager')
		aM=audioManager;
	end
	aM.silentMode = false;
	if ~aM.isSetup;	aM.setup; end
	
	%==============================================STIMULUS
	ball = imageStimulus('name','ball');
	ball.filePath = in.image;
	ball.xPosition = startX1;
	ball.yPosition = sv.bottomInDegrees - in.floor - ballSize - 0.2;
	ball.angle = 0;
	ball.speed = 0;
	ball.size = ballSize;
	radius = ball.size/2;
	startx = ball.xPosition;
	starty = ball.yPosition;

	%===============================================TOUCH
	tM = touchManager('isDummy',in.dummy,'verbose',verbose);
	tM.window.radius = radius;
	tM.window.X = startx;
	tM.window.Y = starty;
	
	%setup some other parameters
	nTrials = 500;
	moveWallAfterNCorrectTrials = 3;
	nCorrect = 0;
	RestrictKeysForKbCheck(KbName('ESCAPE'));

	dateStamp = initialiseSaveFile(s);
	fileName = [s.paths.savedData filesep 'DragTraining-' dateStamp '-.mat'];

	%==============================================WALLS
	floor = barStimulus('name','floor','colour',[0.8 0.4 0.4 0.2],'barWidth',sv.widthInDegrees,...
	'barHeight',0.2,'yPosition',sv.bottomInDegrees-in.floor);
	ceiling = floor.clone;
	ceiling.name = 'ceiling';
	ceiling.yPosition = sv.topInDegrees;
	
	wall1 = barStimulus('name','wall1','colour',[0.4 0.8 0.4 0.2],'barWidth',0.1,'barHeight',...
		sv.heightInDegrees,'xPosition',in.leftW);
	wall2 = clone(wall1);
	wall2.name = 'wall2';
	wall2.xPosition = in.rightW;

	walls = metaStimulus('stimuli',{floor, ceiling, wall1, wall2});

	%===============================================ANIMMANAGER
	anmtr = animationManager('timeDelta', sv.ifi, 'verbose', verbose);
	anmtr.rigidParams.linearDamping = airResistanceCoeff;
	anmtr.addBody(floor,'Rectangle','infinite');
	anmtr.addBody(ceiling,'Rectangle','infinite');
	anmtr.addBody(wall1,'Rectangle','infinite');
	anmtr.addBody(wall2,'Rectangle','infinite');
	anmtr.addBody(ball,'Circle','normal',10, 0.8, 0.8, ball.speed/2);

	% bump our priority
	Priority(1);

	% setup the objects
	setup(ball, s);
	setup(walls, s);
	setup(tM, s);
	setup(anmtr, s);
	createQueue(tM);
	start(tM);

	% our results structure
	anidata = struct('N',NaN,'t',[],'x',[],'y',[],'dx',[],'dy',[],...
		'ke',[],'pe',[]);
	results = struct('N',[],'correct',[],'wallPos',[],...
		'RT',[],'date',dateStamp,'name',fileName,...
		'anidata',anidata);

	[ballb, ballidx] = anmtr.getBody('ball');
	[incorrectWall, ~, iIDX] = anmtr.getBody('wall1');
	[correctWall, ~, cIDX] = anmtr.getBody('wall2');
	
	for j = 1:nTrials

		results.anidata(j).N = j;
		fprintf('--->>> Trial: %i - Wall: %.1f\n', j,1);
		ball.xPositionOut = startx;
		ball.yPositionOut = starty;
		ball.update;
		ballb.setGravityScale(1);
		tM.window.X = ball.xFinalD;
		tM.window.Y = ball.yFinalD;
		
		% the animator needs to be reset to the ball on each trial
		update(anmtr);
		
		xy = []; tx = []; ty = []; iv = round(sv.fps/5);
		correct = false;
		countDown = 30;
		correctCollide = false;
		incorrectCollide = false;
		inTouch = false;
		drawBackground(s, s.backgroundColour);
		flush(tM);
		vbl = flip(s); tStart = vbl;

		while ~correct && vbl < tStart + 15
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
					if tM.y+radius > (floor.yPosition) % make sure we don't move below the floor
						ball.updateXY(e.MappedX, toPixels(s,floor.yPosition-radius,'y'), false);
					else
						ball.updateXY(e.MappedX, e.MappedY, false);
					end
					tx = [tx tM.x];
					ty = [ty tM.y];
					if length(tx) >= iv %collect enough samples
						xy = [tx(end-(iv-1):end)' ty(end-(iv-1):end)'];
						vx = mean(diff(xy(:,1))) * iv * touchSensitivity;
						vy = mean(diff(xy(:,2))) * iv * touchSensitivity;
						av = vx / 2;
						x = xy(end,1);
						y = xy(end,2);
						fprintf('UPDATE X: stim%.1f evt%.1f anim%.1f n%.1f v%.1f Y: stim%.1f evt%.1f anim%.1f n%.1f v%.1f A: %.1f\n', ...
								ball.xFinal,e.MappedX,anmtr.x,x,vx,ball.yFinal,e.MappedY,anmtr.y,y,vy,av);
						anmtr.editBody(ballb,x,y,vx,vy,av);
					else
						anmtr.editBody(ballb,tM.x,tM.y);
					end
				else
					step(anmtr);
					ball.updateXY(anmtr.x, anmtr.y, true);
					a = anmtr.angularVelocity(ballidx);
					ball.angleOut = ball.angleOut + (rad2deg(a) * anmtr.timeDelta);
				end
				fprintf('\n');
			else
				step(anmtr);
				ball.updateXY(anmtr.x, anmtr.y, true);
				a = anmtr.angularVelocity(ballidx);
				ball.angleOut = ball.angleOut + (rad2deg(a) * anmtr.timeDelta);
			end
			[coll, otherBody] = isCollision(anmtr, ballb);
			if coll && otherBody.hashCode == anmtr.bodies(cIDX).hash
				correctCollide = true;
			elseif coll && otherBody.hashCode == anmtr.bodies(iIDX).hash
				incorrectCollide = true;
			end
			if correctCollide
				ballb.setGravityScale(0.1);
				countDown = countDown - 1;
				if countDown == 0
					correct = true;
				end
			elseif incorrectCollide
				ballb.setGravityScale(0.1);
				countDown = countDown - 1;
				if countDown == 0
					break;
				end
			end
			draw(ball);
			draw(walls);
			vbl = flip(s, vbl + sv.halfifi);
			% save all animation data for each trial, we can use this to "play
			% back" the action performed by the monkey
			results.anidata(j).t =  [results.anidata(j).t, anmtr.timeStep];
			results.anidata(j).x =  [results.anidata(j).x, anmtr.x];
			results.anidata(j).y =  [results.anidata(j).y, anmtr.y];
			results.anidata(j).dx = [results.anidata(j).dx, anmtr.dX];
			results.anidata(j).dy = [results.anidata(j).dy, anmtr.dY];
			results.anidata(j).ke = [results.anidata(j).ke, anmtr.kineticEnergy];
			results.anidata(j).pe = [results.anidata(j).pe, anmtr.potentialEnergy];
		end

		if KbCheck; break; end

		results.N = [results.N j];
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
			if nCorrect >= moveWallAfterNCorrectTrials
				nCorrect = 0;
			end
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

	Priority(0);
	RestrictKeysForKbCheck([]);
	disp(['--->>> DATA saved to ' fileName]);
	save(fileName,"results");
	tM.close;
	ball.reset;
	walls.reset;
	s.close;

	plot(in.axis1, results.anidata(end).x,results.anidata(end).y,'-');
		xlabel(in.axis1,'X Position');
		ylabel(in.axis1, 'Y Position');
		plot(in.axis2, results.N, results.correct,'.-');

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
	try tM.close; end
	try ball.reset; end
	try s.close; end
	try sca; end
	rethrow(ERR);
end

function array = push(array, value)
	array = [array value];
end

end