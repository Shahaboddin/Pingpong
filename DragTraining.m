function DragTraining()
	%==============================================Screen
	
	ballSize = 4;
	startX1 = -4;
	startX2 = 10;
	airResistanceCoeff = 0.1;
	elasticityCoeff = 0.8;
	leftWall = -15;
	rightWall = 5;
	correctWall = rightWall;
	
	%===============================================
	% this modifies the touch movement > velocity
	% higher values means bigger impact
	touchSensitivity = 6;
	% set up the walls
	floorThickness = 7;
	wallThickness = 1;
	
	try 
		s = screenManager;
		s.backgroundColour = [0 0.2 0.1];
		s.windowed = [];
		s.specialFlags = 0;
		sv = open(s);
		
		%==============================================Arduino initialization
		rwd_front = arduinoManager('port','/dev/ttyACM1','shield','new');
		rwd_front.silentMode = false;
		rwd_front.open;
		
		%==============================================Audio Manager
		if ~exist('aM','var') || isempty(aM) || ~isa(aM,'audioManager')
			aM=audioManager;
		end
		aM.silentMode = false;
		if ~aM.isSetup;	aM.setup; end
		
		%==============================================STIMULUS
		ball = imageStimulus;
		ball.filePath = 'ball2.png';
		ball.xPosition = startX1;
		ball.yPosition = sv.bottomInDegrees-ballSize-0.5;
		ball.angle = 0;
		ball.speed = 1;
		ball.size = ballSize;
		radius = ball.size/2;
		startx = ball.xPosition;
		starty = ball.yPosition;
		
		%===============================================ANIMMANAGER
		anmtr = animationManager;
		anmtr.rigidparams.radius = radius;
		anmtr.rigidparams.mass = 5;
		anmtr.rigidparams.airResistanceCoeff = airResistanceCoeff;
		anmtr.rigidparams.elasticityCoeff = elasticityCoeff;
		anmtr.timeDelta = sv.ifi;
		
		%===============================================TOUCH
		tM = touchManager('isDummy',false, 'panelType',1);
		tM.verbose = false;
		tM.window.radius = radius;
		tM.window.X = startx;
		tM.window.Y = starty;
		%=============================
		%=============================
		%=============================
		%=============================
		%setup some other parameters
		nTrials = 5;
		moveWallAfterNCorrectTrials = 3;
		nCorrect = 0;
		RestrictKeysForKbCheck(KbName('ESCAPE'));
	
		dateStamp = initialiseSaveFile(s);
		fileName = [s.paths.savedData filesep 'DragTraining-' dateStamp '-.mat'];
	
		% left,top,right,bottom
		floorrect = [sv.leftInDegrees sv.bottomInDegrees-floorThickness sv.rightInDegrees sv.bottomInDegrees];
		wall1 = [leftWall sv.topInDegrees leftWall+wallThickness sv.bottomInDegrees];
		wall2 = [rightWall sv.topInDegrees rightWall+wallThickness sv.bottomInDegrees];
	
		% assign wall positions to anim-manager
		anmtr.rigidparams.leftwall = wall1(3);
		anmtr.rigidparams.rightwall = wall2(1);
		anmtr.rigidparams.floor = sv.bottomInDegrees-floorThickness;
		anmtr.rigidparams.ceiling = sv.topInDegrees;
	
		% bump our priority
		Priority(1);
	
		% setup the objects
		setup(ball, s);
		setup(tM, s);
		setup(anmtr, ball);
		createQueue(tM);
		start(tM);
	
		% our results structure
		anidata = struct('N',NaN,'t',[],'x',[],'y',[],'dx',[],'dy',[],...
			'ke',[],'pe',[]);
		results = struct('N',[],'correct',[],'wallPos',[],...
			'RT',[],'date',dateStamp,'name',fileName,...
			'anidata',anidata);
		
		for j = 1:nTrials
	
			results.anidata(j).N = j;
			fprintf('--->>> Trial: %i - Wall: %.1f\n', j,correctWall);
			ball.xPositionOut = startx;
			ball.yPositionOut = starty;
			ball.update;
			
			% the animator needs to be reset to the ball on each trial
			anmtr.rigidparams.rightwall = wall2(1);
			anmtr.rigidparams.airResistanceCoeff = 0.5;
			reset(anmtr);
			setup(anmtr, ball);
			
			xy = []; tx = []; ty = []; iv = round(sv.fps/10);
			correct = false;
			countDown = 10;
			inTouch = false;
			drawBackground(s, s.backgroundColour)
			flush(tM);
			vbl = flip(s); tStart = vbl;
	
			while ~correct && vbl < tStart + 5
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
						if tM.y+radius > (floorrect(2)) % make sure we don't move below the floor
							ball.updateXY(e.MappedX, toPixels(s,floorrect(2)-radius,'y'), false);
						else
							ball.updateXY(e.MappedX, e.MappedY, false);
						end
						tx = [tx tM.x];
						ty = [ty tM.y];
						if length(tx) >= iv %collect enough samples
							xy = [tx(end-(iv-1):end)' ty(end-(iv-1):end)'];
							vx = mean(diff(xy(:,1))) * iv * touchSensitivity;
							vy = mean(diff(xy(:,2))) * iv * touchSensitivity;
							x = mean([anmtr.x xy(end,1)]);
							y = mean([anmtr.y xy(end,2)]);
							%fprintf('UPDATE X: s%.1f e%.1f a%.1f n%.1f v%.1f Y: s%.1f e%.1f a%.1f n%.1f v%.1f\n', ...
							%       i.xFinal,e.MappedX,a.x,x,vx,i.yFinal,e.MappedY,a.y,y,vy);
							anmtr.editBody(x,y,vx,vy);
						else
							anmtr.editBody(tM.x,tM.y);
						end
					else
						animate(anmtr);
						ball.updateXY(anmtr.x, anmtr.y, true);
						ball.angleOut = -rad2deg(anmtr.angle);
					end
				else
					animate(anmtr);
					ball.updateXY(anmtr.x, anmtr.y, true);
					ball.angleOut = -rad2deg(anmtr.angle);
				end
				if anmtr.hitLeftWall
					anmtr.rigidparams.airResistanceCoeff = 5;
					countDown = countDown - 1;
					if countDown == 0
						break;
					end
				elseif anmtr.hitRightWall
					anmtr.rigidparams.airResistanceCoeff = 5;
					countDown = countDown - 1;
					if countDown == 0
						correct = true;
					end
				end
				draw(ball);
				if anmtr.hitLeftWall
					drawRect(s,wall1,[0.6 0.3 0.3]);
				else
					drawRect(s,wall1,[0.3 0.3 0.3]);
				end
				if anmtr.hitRightWall
					drawRect(s,wall2,[0.3 0.6 0.3]);
				else
					drawRect(s,wall2,[0.3 0.3 0.3]);
				end
				drawRect(s,floorrect,[0.3 0.3 0.3]);
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
			results.wallPos = [results.wallPos correctWall];
			results.RT = [results.RT (tStart - GetSecs)];
	
			if correct
				nCorrect = nCorrect + 1;
				drawBackground(s, [0.3 0.6 0.3]);
				flip(s);
				giveReward(rwd_front);
				beep(aM, 3000,0.1,0.1);
				rwd_front.stepper(46);
				disp('--->>> CORRECT');
				WaitSecs(2);
				if nCorrect >= moveWallAfterNCorrectTrials
					nCorrect = 0;
					if correctWall < sv.rightInDegrees - 1
						disp('Wall moved...');
						correctWall = correctWall + 1;
					end
					wall2 = [correctWall sv.topInDegrees correctWall+wallThickness sv.bottomInDegrees];
				end
			else
				disp('--->>> FAIL');
				beep(aM, 300,0.5,0.5);
				drawBackground(s, [0.6 0.3 0.3]);
				flip(s);
				WaitSecs(3);
			end
		end
	
		Priority(0);
		RestrictKeysForKbCheck([]);
		disp(['--->>> DATA saved to ' fileName]);
		save(fileName,"results");
		tM.close;
		ball.reset;
		s.close;
	
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