%% enable encryption on PM
nnp.nmt(7, 'BA', 1)
% enable encryption on AP
nnp.transmitAP(hex2dec('4f'), 1)

%% disable encryption on PM
nnp.nmt(7, 'BA', 0)
% disable encryption on AP
nnp.transmitAP(hex2dec('4f'), 0)


%% reset WL
nnp.transmitAP(hex2dec('23'))
%% turn off acc
nnp.transmitAP(hex2dec('33'), 0)
%%
%Set Address
address= 0;
nnp.write(7, '2020', 1, address, 'uint32')
% trigger read
memSelect = 2;
nnp.nmt(7, hex2dec('E8'), memSelect)
status = nnp.read(7, '2020', 7, 'uint8')
% read Address
addressRead = nnp.read(7, '2020', 1, 'uint32')
%% read Data
dataRX = nnp.read(7, '2020', 2, 'uint8')
%%
addressback = typecast(dataRX(end-3:end), 'uint32')
%%
status = nnp.read(7, '2020', 7, 'uint8')
%%
nnp.readMemory(7,2,0,512,true,true)
%% 
nnp.read(7, 'a200', 3)