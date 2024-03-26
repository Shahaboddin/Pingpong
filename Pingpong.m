s=screenManager;
s.backgroundColour = [ 0 0.3 0.2];
s.screen = 1;

%==============================================Arduino initialization
a_front = arduinoManager('port','/dev/ttyACM0','shield','new'); a_front.open;

%==============================================Audio Manager
if ~exist('aM','var') || isempty(aM) || ~isa(aM,'audioManager')
	aM=audioManager;
end
aM.silentMode = false;
if ~aM.isSetup;	aM.setup; end

%==============================================STIMULUS
stim= imageStimulus;
stim.filePath = 'ball2.png';
stim.xPosition = -1;
stim.yPosition = 4;
stim.size = 2;
radius = stim.size/2;

ox = stim.xPosition;
oy = stim.yPosition;

t = touchManager('isDummy',false);
t.verbose=true;

RestrictKeysForKbCheck(KbName('ESCAPE'));

try

	sv = s.open;

	% [left, top, right, bottom];
	wallRect = [2 -2 4 8];
	xlim = 2.5 - radius;

	stim.setup(s);
	floorRect = [sv.leftInDegrees sv.bottomInDegrees-0 sv.rightInDegrees sv.bottomInDegrees];

	ylim = sv.bottomInDegrees - 1 - radius;
	t.setup(s);

	t.createQueue;
	t.start;

	for j = 1:20

		fprintf('trial: %d\n', j);
		s.flip;
		stim.xPositionOut = ox;
		stim.yPositionOut = oy;
		stim.update;

		t.window.X = s.toDegrees(stim.xFinal,'x');
		t.window.Y = s.toDegrees(stim.yFinal,'y');
		t.window.radius = radius;

		doDrag = false;

		for i = 1:300

			if KbCheck; break; end

			if doDrag == false && t.checkTouchWindows == true
				doDrag = true;
			end

			if doDrag == true && t.eventAvail
				e = t.getEvent;
				if e.Type == 2 || e.Type == 3
					%fprintf('%.2f %.2f %.2f %.2f\n, stim.yFinalD, ylim, stim.xFinalD, xlim')
					if stim.yFinalD < ylim && stim.xFinalD < xlim
						if e.xy(1)>xlim; x = xlim; else x = e.xy(1); end
						if e.xy(2)>ylim; y = ylim; else y = e.xy(2); end
						stim.updateXY(x, y, true);
					else
						fprintf('Reward!\n');
						aM.beep(2000,0.1,0.1);
						a_front.stepper(46);
						break;
					end
				elseif e.Type == 4
					stim.xPositionOut = ox;
					stim.yPositionOut = oy;
					stim.update;
					doDrag = false;
				end
			end

			s.drawRect(wallRect,[0.5 0.8 0.5]);
			stim.draw;
			s.drawRect(floorRect,[0.5 0.8 0.5]);
			s.flip;
			
		end

		if KbCheck; break; end
		s.flip;
		WaitSecs(3);

	end

	t.close;
	stim.reset;
	s.close;

catch ME
	getReport(ME);
	try t.close; end
	try stim.reset; end
	try s.close; end
	rethrow(ME);
end
