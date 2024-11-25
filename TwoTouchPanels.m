function twoTouchPanels()

	a_front = arduinoManager('port','/dev/ttyACM0','shield','new'); a_front.open;
	a_back  = arduinoManager('port','/dev/ttyACM1','shield','new'); a_back.open;
	
	eyeTrigger1 = dataConnection('protocol','udp','rPort',35000,'rAddress','10.10.47.122');
	open(eyeTrigger1);
	eyeTrigger2 = dataConnection('protocol','udp','rPort',35002,'rAddress','10.10.47.122');
	open(eyeTrigger2);
	
	
	%Audio Manager
	if ~exist('aM','var') || isempty(aM) || ~isa(aM,'audioManager')
		aM=audioManager;
	end
	aM.silentMode = false;
	if ~aM.isSetup;	aM.setup; end
	
	stims			= {'stimFron', 'stimBack'};%, 'other', 'both'};
	trialN          = 20 ;
	choiceTouch     = [1 2];
	
	debug			= false;
	dummy			= false;
	timeOut			= 4;
	nObjects		= length(stims);
	stimSize		= 20;
	circleRadius	= 12;
	degsPerStep		= 360 / nObjects;
	pxPerCm			= 16;
	distance		= 20;
	centerY			= 20;
	centerX			= 0;
	colourFron		= [0.8 0.5 0.3];
	colourBack		= [0.3 0.5 0.8];
	randomise		= true;
	taskType        = 'com';
	try
		%==============================================CREATE SCREEN
		s = screenManager('blend', true,'antiAlias', 8,'backgroundColour', [0 0 0],...
			'pixelsPerCm', pxPerCm,'distance', distance,...
			'screenXOffset', centerX,'screenYOffset', centerY);
		open(s);
	
		%==============================================INITIATE THE TOUCHPANELS
		tMFron = touchManager('device',choiceTouch(1),'isDummy',dummy);
		tMBack = touchManager('device',choiceTouch(2),'isDummy',dummy);
		setup(tMFron, s);
		setup(tMBack, s);
		
		%==============================================CREATE STIMULI
		stimFron= barStimulus('size', stimSize, 'colour', colourFron,'speed',0);
		stimBack= barStimulus('size', stimSize, 'colour', colourBack,'speed',0);
		setup(stimFron, s);
		setup(stimBack, s);
	
		%==============================================GET SUBJECT NAME
		subject= input ("Enter subject name:",'s');
		nameExp=[subject,'-',date,'.mat'];
		
		%==============================================
		text='Please press ESCAPE to start experiment...';
		drawTextNow(s,text);    
		RestrictKeysForKbCheck(KbName('ESCAPE'));
		KbWait;
	
	
		correctTrials.Fron	= 0;
		correctTrials.Back	= 0;
		correctTrials.Coop  = 0;
	
	% 	reactionTimeFron.init	= GetSecs;
	% 	reactionTimeBack.init	= GetSecs;
		reactionTime.Coop       = zeros(trialN, 1);
		reactionTime.Fron	    = zeros(trialN, 1);
		reactionTime.Back	    = zeros(trialN, 1);
	% 	reactionTimeFron.both	= zeros(trialN, 1);
	% 	reactionTimeFron.none	= zeros(trialN, 1);
	
		%==============================================START TOUCH QUEUE
		try Priority(1); end
		createQueue(tMFron);
		createQueue(tMBack);
		
		start(tMFron);
		text='Please touch the screen...';
		drawTextNow(s,text);
		start(tMBack);
	
		eyeTrigger1.write(int32(10000));
		eyeTrigger2.write(int32(10000));
		eyeTrigger1.write(int32(10000));
		eyeTrigger2.write(int32(10000));
		%==============================================MAIN TRIAL LOOP
		for iTrial=1:trialN
			fprintf('\n===>>> Running Trial %i\n',iTrial);
	
			% ----- set the positions for this trial
	% 		randOffset = round(rand * 360);
	% 		for jObj = 1 : nObjects
	% 			theta = deg2rad((degsPerStep * jObj) + randOffset);
	% 			[x,y] = pol2cart(theta, circleRadius);
	% 			eval([stims{jObj} '.xPositionOut = ' num2str(x) ';']);
	% 			eval([stims{jObj} '.yPositionOut = ' num2str(y) ';']);
	% 		end
			stimFron.xPositionOut = -40;  stimFron.yPositionOut=25;
			stimBack.xPositionOut =  40;  stimBack.yPositionOut=25;
			% ----- randomise
			if randomise
				stimFron.colourOut		= [lim(rand) lim(rand) lim(rand)];
				stimBack.colourOut		= [lim(rand) lim(rand) lim(rand)];
	% 			both.colourOut		= [lim(rand) lim(rand) l12im(rand)];
	% 			none.colourOut		= [lim(rand) lim(rand) lim(rand)];
	% 			stimFron.angleOut		= rand * 360;
	% 			stimBack.angleOut		= rand * 360;
	% % 			both.angleOut		= rand * 360;
	% 			none.angleOut		= rand * 360;
			end
			% ----- update stimuli with new values
			update(stimFron); update(stimBack); %update(both); update(none);
	 
			% ====================================SHOW STIMULI
			
			rewardFron = false; rewardBack = false; %bothReward = false; noneReward = false;
			touchFron = false; touchBack=false;cWins = [];
			%x = []; y = []; txt = ''; textMonkey = ''; 
			flush(tMFron);
			flush(tMBack);
	
			vbl = flip(s); tStart = vbl;
			a = 0;
			while vbl <= (tStart + timeOut) && touchFron == false && touchBack==false
				for jObj = 1 : nObjects
					% we use eval as our object names are stored in an array
					eval(['draw(' stims{jObj} ');']);
					eval(['cWins(jObj,:) = toDegrees(s, ' stims{jObj} '.mvRect, ''rect'');']);
				end
				if debug; drawScreenCenter(s); drawGrid(s); drawText(s, txt); end %#ok<*UNRCH> 
				vbl = flip(s);
	
				if a == 0; eyeTrigger1.write(int32(iTrial)); eyeTrigger2.write(int32(iTrial)); a = 1; end
	
	
				[resultsFron, xFron, yFron] = checkTouchWindows(tMFron, cWins(1,:));
				[resultsBack, xBack, yBack] = checkTouchWindows(tMBack, cWins(2,:));
				if ~any([resultsFron resultsBack]); continue; end
	
				switch taskType
					case {'competition','com'}
						if any(resultsFron)
							disp('front monkey win');
							touchFron=true;
							correctTrials.Fron        = correctTrials.Fron+1;
							reactionTime.Fron(iTrial) = GetSecs-tStart;
						elseif any(resultsBack)
							disp('back monkey win');
							touchBack=true;
							correctTrials.Back        = correctTrials.Back+1;
							reactionTime.Back(iTrial) = GetSecs-tStart;
						end
						if any(resultsFron)||any(resultsBack)
							flip(s);
	% 						 break;
						end
					case{'cooperation','coo'}
						if any(resultsFron)
							touchFron=true;
							disp('front monkey touch first');
	% 						correctTrials.Fron        = correctTrials.Fron+1;
	% 						reactionTime.Fron(iTrial) = GetSecs-tStart;
							draw(stimBack);
							tleft                     = timeOut-reactionTime.Fron(iTrial);
							vbl2 = flip(s);   tStart2 = vbl2;
							while ~any(resultsBack)&&vbl2<tStart2+tleft							
								resultsBack = checkTouchWindows(tMBack, cWins);
								draw(stimBack);
								vbl2=flip(s);
							end
							if any(resultsBack)
								touchBack=true;
								correctTrials.Coop=correctTrials.Coop+1;
								reactionTime.Coop(iTrial) = GetSecs-tStart;
								disp('then the back monkey touch')
								flip(s);
								break
							end
						
						elseif any(resultsBack)
							touchBack = true;
							disp('back monkey touch first')
	% 						correctTrials.Back        = correctTrials.Back+1;
	% 						reactionTime.Back(iTrial) = GetSecs-tStart;
							draw(stimFron);
							tleft                     = timeOut-reactionTime.Back(iTrial);
							vbl2   =  flip(s); tStart2=vbl2;
							while ~any(resultsFron)&&vbl2<tStart2+tleft
								resultsFron = checkTouchWindows(tMFron, cWins);
								draw(stimFron);
								vbl2=flip(s);
							end
						
							if any(resultsFron)
								touchFron=true;
								correctTrials.Coop        = correctTrials.Coop+1;
								reactionTime.Coop(iTrial) = GetSecs-tStart;
								disp('then the front monkey touch')
								flip(s);
								break
							end
						end
					case{'co-action','coa'}
						if  any(resultsFron)
							touchFron=true;
							aM.beep(2000,0.1,0.1);
							a_front.stepper(46);
							disp('front monkey touch first');
							correctTrials.Fron        = correctTrials.Fron+1;
							reactionTime.Fron(iTrial) = GetSecs-tStart;
							draw(stimBack);
							tleft                     = timeOut-reactionTime.Fron(iTrial);
							vbl2 = flip(s);   tStart2 = vbl2;
							while ~any(resultsBack)&&vbl2<tStart2+tleft
								resultsBack = checkTouchWindows(tMBack, cWins);
								draw(stimBack);
								vbl2=flip(s);
							end
							if any(resultsBack)
								correctTrials.Coop=correctTrials.Coop+1;
								reactionTime.Coa(iTrial) = GetSecs-tStart;
								aM.beep(2000,0.1,0.1);
								a_back.stepper(46);
								disp('then the back monkey touch')
								flip(s);
								break;
							end
	
						elseif any(resultsBack)
							touchBack = true;
							aM.beep(2000,0.1,0.1);
							a_back.stepper(46);
							disp('back monkey touch first')
							correctTrials.Back        = correctTrials.Back+1;
							reactionTime.Back(iTrial) = GetSecs-tStart;
							draw(stimFron);
							tleft                     = timeOut-reactionTime.Back(iTrial);
							vbl2   =  flip(s); tStart2=vbl2;
							while ~any(resultsFron)&&vbl2<tStart2+tleft
								resultsFron = checkTouchWindows(tMFron, cWins);
								draw(stimFron);
								vbl2=flip(s);
							end
	
							if any(resultsFron)
								correctTrials.Coop        = correctTrials.Coop+1;
								reactionTime.Coa(iTrial) = GetSecs-tStart;
								aM.beep(2000,0.1,0.1);
								a_front.stepper(46);
								disp('then the front monkey touch')
								flip(s);
								break
							end
						end
						
				end
				if debug && ~isempty(xFron)correctTrialsFron; txt = sprintf('x = %.2f Y = %.2f',xFron(1),yFron(1)); end
			end % END WHILE
			
			eyeTrigger1.write(int32(0));
			eyeTrigger2.write(int32(0));		
			
			% =============================REWARDS
			if debug; drawTextNow(s,textMonkey); end
			switch taskType
				case{'competition','com'}
					if touchFron
						aM.beep(2000,0.1,0.1);
						a_front.stepper(46);
					elseif touchBack
						aM.beep(2000,0.1,0.1);
						a_back.stepper(46);
					end
				case{'cooperation','coo'}
					flip(s);
					if touchFron&&touchBack
						aM.beep(2000,0.1,0.1);
						a_front.stepper(46);
						a_back.stepper(46);
					end
					WaitSecs(1)
			end
			WaitSecs(2);
	
		end
	
	
	% 	reactionTimeFron.end   = GetSecs;
	% 	reactionTimeFron.total = reactionTimeFron.end - reactionTimeFron.init;
	
		% say we finish experiment
		eyeTrigger1.write(int32(-500));
		eyeTrigger2.write(int32(-500));
		
	% 	a_front.close;a_back.close;
	
		% =====================================SAVE DATA
		results                   = struct();
		results.stims             = stims;
		results.taskType          = taskType;
		results.correctTrials = correctTrials;
	% 	results.correctTrialsBack =
		results.reactionTime = reactionTime;
		results.subject = subject;
		results.trialN = trialN;
	% 	results.TotalTime = reactionTimeFron.total;
		cd(s.paths.savedData);
		save(nameExp, 'results');
	
		% ====================================CLEAN UP
		close(s);
		close(tMFron);
		close(tMBack)
		reset(stimFron); reset(stimBack); %reset(both); reset(none);
		Priority(0); ShowCursor; sca;
	
	catch E
	
		try close(s); end %#ok<*TRYNC> 
		try close(tM); end
	% 	reset(stimFron); reset(stimBack); reset(both); reset(none);
		Priority(0); ShowCursor; sca;
		rethrow(E);
	end
	
	function out = lim(in)
		l = 0.4; h = 0.8;
		out = (in * (h - l))+l;
	end
	
	end % END FUNCTION`
	 % END FUNCTION