classdef BPSTREAMING < NNPHELPERS
%--------- variables
    
properties (Access = public)
    emgTimer = [];
    emgSamp = [];
    emgbuf = [];
    emgLogFileName = "";
end

methods (Access = public)

    %---------------------------------------------------------------------------------
    function startupFcn(NNP)
        NNP.setRadio('timeout', 10, 'retries', 0');
        NNP.worOff();
        NNP.networkOn;
        NNP.enterWaiting;
        pause(.2); % allow time for all nodes to start up

        NNP.emgTimer = timer();
        NNP.emgTimer.Period = 0.025;
        NNP.emgTimer.ExecutionMode = 'fixedRate';
        NNP.emgTimer.BusyMode = 'drop';
        % NNP.emgTimer.TimerFcn = @updateEMG;
        NNP.emgTimer.TimerFcn = @NNP.updateEMGfile;

        NNP.emgSamp = 1000;
        NNP.emgbuf = nan(NNP.emgSamp, 1);
    end
    %---------------------------------------------------------------------------------
    % Value changed function: setGain
    function setGain(NNP, node, gain)
        
        if ~NNP.setBPGains(node, gain, gain)
            msgbox('Gains not set')
        end
    end
    %---------------------------------------------------------------------------------              
    function startEMG(NNP, rnode, rch)

        if ~NNP.enterTestRaw(rnode, rch)
            msgbox('Could not enter Raw MES mode')
        end
        start(NNP.emgTimer); %not log data to file
    end
    %---------------------------------------------------------------------------------   
    function stopEMG(NNP)
    
        stop(NNP.emgTimer);

    end
    %---------------------------------------------------------------------------------
    function updateEMGfile(NNPin, src, event)  
        resp = NNPin.read(7, '2053', 3, 'uint8');
        NNPin.emgbuf(1:end-48) = NNPin.emgbuf(49:end);
        if length(resp) == 49
            newdata = resp(1:48)';
        else
            newdata = nan(48,1); %
        end
        NNPin.emgbuf(end-48+1:end) = newdata;
        % If I update every cycle, then I am updating the plot at 20
        % Hz.  Could probably update slower, like 10 or 5 hz.  To do
        % that I could have a running counter to determine when to
        % update.
        writematrix(newdata, NNPin.emgLogFileName, 'WriteMode', 'append');
    end
    %---------------------------------------------------------------------------------              
    function  startStim(NNP, snode, schan, spw, spa)    
        NNP.networkOn;
        NNP.enterTestStim;
        NNP.write(snode, '3212', schan, uint8([spw spa])); % result for error check
    end
    %---------------------------------------------------------------------------------              
    function stopStim(NNP)   
    
        % When stimulating and recording EMG, it is more likely for the
        % remove modules to miss the enterwaiting command.  Therefore I am
        % going to turn off the network when stim stops to ensure they stop
        if ~NNP.enterWaiting()  %needs to be in waiting before network can be turned off, resp=1 is success
            msgbox('Could not enter waiting');
        end
        pause(.1)
    end
    %---------------------------------------------------------------------------------
    function closeout(NNP)

        delete(NNP.emgTimer)
        delete(NNP)
    end
end
end