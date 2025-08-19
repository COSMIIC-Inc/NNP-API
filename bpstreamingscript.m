%--------- variables
bp_node = 2;
bp_channel = 1;
bp_gain = 100;

pg_node = 6;
pg_channel = 1;
pg_pw = 50;
pg_pa = 5;

stimfreq = 40;
%--------- script
nnp=BPSTREAMING();
nnp.emgLogFileName='TempLogFileName.csv'; % Save this to a temporary file

% repeat whole block to make sure radio and network settings are corrected
% after the stopEMG and stopStim functions because they do not handle
% network changes.
startupFcn(nnp);
setGain(nnp, bp_node, bp_gain); %BP2 node 2, 100 gain
nnp.setSync(1000/stimfreq);
startEMG(nnp, bp_node, bp_channel); % BP2 node 2, channel 1
startStim(nnp, pg_node, pg_channel, pg_pw, pg_pa*10);
stopEMG(nnp);
stopStim(nnp);


%% delete timer and nnp to avoid conflicts
closeout(nnp);