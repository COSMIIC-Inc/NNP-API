for i=1:1000 
    %%
resp = nnp.transmitAP(hex2dec('46'));
 vbat = double(typecast(uint8(resp), 'int16'));


 resp = nnp.transmitAP(hex2dec('41'));
 fprintf('%4.0f 0x%02X\n', vbat, resp)
 %%
 pause(5)
end
 %%
nnp.transmitAP(hex2dec('42'), [1 8 0 0 50])

nnp.transmitAP(hex2dec('42'), [5 8 0 0 100 0 0 0 100 4 0 0 100 0 0 0 100 2 0 0 200])

%%
notes = [130.81 146.83 164.81 174.61 196 220 246.94 ...
        261.63 293.66 329.63 349.23 392 440 493.88]; ...
          %523.25 587.33 659.25 698.46 783.99 880 987.77];...
         %1046.5 1174.66 1318.51 1396.91 1567.98 1760 1975.53 2093]

n = length(notes)

noteperiods = uint16(round(1./notes*1000000))

notelengths = uint16(ones(1, n)*100);

A = reshape([noteperiods; notelengths], 1, n*2)

B = typecast(swapbytes(A), 'uint8')


nnp.transmitAP(hex2dec('42'), [n B])


%%
notes = [ 440 ]

n = length(notes)

noteperiods = uint16(round(1./notes*1000000))

notelengths = uint16(ones(1, n)*1000);

A = reshape([noteperiods; notelengths], 1, n*2)

B = typecast(swapbytes(A), 'uint8')


nnp.transmitAP(hex2dec('42'), [n B])

%nnp.getSerial(7)
%%
nnp.refresh
%%
nnp.transmitAP(hex2dec('31'), [0,1])
nnp.transmitAP(hex2dec('31'), [1,1])
nnp.transmitAP(hex2dec('31'), [2,1])
nnp.transmitAP(hex2dec('31'), [3,1])
%%

nnp.transmitAP(hex2dec('30'), [1 71 12 52 0 1 7 0 0 0 1 150])
%% Configure long press of button 1 to put WL into low power mode
nnp.transmitAP(hex2dec('30'), [2 hex2dec('43') 3 0])
%%
nnp.transmitAP(hex2dec('30'), [0 71 12 52 0 1 7 0 0 0 1 149])
%%
nnp.transmitAP(hex2dec('30'), [3 hex2dec('33') 3 0])

%%
nnp.transmitAP(hex2dec('30'), [1 71 11 sscanf('A4 00 01 07 20 30 04 01 00', '%02X')'])
%%
nnp.transmitAP(hex2dec('30'), [0 71 11 sscanf('A4 00 01 07 20 30 04 01 FF', '%02X')'])
%%
nnp.transmitAP(hex2dec('30'), [0 71 11 sscanf('A4 00 01 07 53 1F 04 01 05', '%02X')'])
%%
nnp.transmitAP(hex2dec('30'), [1 71 11 sscanf('A4 00 01 07 53 1F 04 01 09', '%02X')'])
%% turn off acc
nnp.refresh
nnp.transmitAP(hex2dec('33'), 0)
%% enterLowPower
nnp.transmitAP(hex2dec('43'),0)


%% start advertising
nnp.transmitAP(hex2dec('44'))
%% stop advertising
nnp.transmitAP(hex2dec('45'))

%% encryption
r = nnp.transmitAP(hex2dec('3f'),uint8('hello world i am secret message read me please now or else what happens'))
fprintf('\n')
fprintf('%02X ', r)
fprintf('\n')
%decryption
p = nnp.transmitAP(hex2dec('40'),r);

char(p)
%%
nnp.trywrite(sscanf('FF 47 11 26 D1 01 07 00 00 00 06 00 00 00 00 30 00', '%02X'))
pause(0.05)
nnp.trywrite(sscanf('FF 47 11 26 D1 01 07 00 00 00 06 30 00 00 00 30 00',  '%02X'))
pause(0.05)
nnp.trywrite(sscanf('FF 47 11 26 D1 01 07 00 00 00 06 60 00 00 00 30 00', '%02X'))
pause(0.05)
%% write image
%create image
k=0;
image = uint8(zeros(1,512));
for i=1:length(image)
    image(i) = k;
    k=k+1;
    if k>255
        k=0; 
    end
end

maxwrite = 248;
n = ceil(length(image)/maxwrite);
pkt = cell(n,1);
for j=1:n
    addr = (j-1)*maxwrite;
    addrBytes = reshape(typecast(uint32(addr), 'uint8'), 1, []);
    if j*maxwrite > length(image)
        pkt{j} = [addrBytes, image((j-1)*maxwrite+1:end)];
    else
        pkt{j} = [addrBytes, image((j-1)*maxwrite+1:j*maxwrite)];
    end
end

tic
for j=1:n
    nnp.transmitAP(36, pkt{j})
    pause(1)
end
toc
%% read image
maxread = 252;
n = ceil(length(image)/maxread);
pkt = cell(n,1);
for j=1:n
    addr = (j-1)*maxread;
    addrBytes = reshape(typecast(uint32(addr), 'uint8'), 1, []);
    if j*maxread > length(image)
        pkt{j} = [addrBytes, rem(length(image), maxread)];
    else
        pkt{j} = [addrBytes, maxread];
    end
end

imageread = [];
tic
for j=1:n
    resp = uint8(nnp.transmitAP(37, pkt{j}));
    if ~isempty(resp)
        imageread = [imageread reshape(resp, 1, [])];
    end
end
toc
imageread
%%
nnp.transmitAP(38, [0 2 0 0 2 0 9])
%%
nnp.transmitAP(38)