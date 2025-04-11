%Encryption and MedRadio Examples
%Requires PM v428 or later and WL
%The PM does not use encryption or MedRadio sessions while in Bootloader Mode
%Encryption and MedRadio are currently disabled by default on PM and WL but will likely be enabled by default in future
%releases

% Encryption Summary:
% The WL and PM have matching fixed keys hardcoded in SW that should not be shared
% The address and length bytes are not encrypted as these are used by the radio hardware for filtering out messages
% The remaining bytes are encrypted (they can no longer be interpreted on the SPI lines via logic analyzer). As part of this
% process, the payload will be padded to have a length that is divisible by 4.  
% Implementation of encryption may add up tp ~2ms of round trip message time WL->PM->WL

% MedRadio Session Summary:
% The MedRadio protocol requires that the external radio monitors available channels (for at least 10ms each) before starting a session.
% A session is maintained by transmitting at least once evry 5s during which the channel is maintained as the quietest monitored channel. 
% Because the PM does not have a priori knowledge of the channel that the WL will use, the PM must listen on each
% channel one by one.  This requires the WL to send out an extra long preamble to guarantee that the PM will detect it.
% Once in a session, the WL can use the standard preamble because the PM will only listen on one channel.  The WL and PM both track how 
% long it has been since they have received a message from the other.  If this time exceeds the Session time, then the PM will return to 
% listening on all channels and the WL will have to initiate a new session
% Definitions:
% * Session: For MedRadio compliance this should be set to 5 (seconds). To use a fixed channel, set the Session to 0
% * Dwell: Amount of time that the external radio will monitor each channel in increments of 10ms. This can also be set
%          to session time.  The maximum RSSI during the dwell time is tracked for each channel.  The lowest value is
%          considered the quietest channel.  Note that if another radio is operating under MedRadio rules, it may only
%          transmit once every 5s and is therefore unlikely to be detected ina  short sampling 
%  * Maintain Session: To avoid the application needing to maintain a session, the WL can maintain the session
%          automatically.  If no message has been sent/received and the session time has almost elapsed, the WL will
%          send out a message and locally handle the response
% 
% See: 
% https://cosmiic.atlassian.net/wiki/download/attachments/516358165/NNP%20Encryption%20for%20Radio.pptx?version=1&modificationDate=1726083590322&cacheVersion=1&api=v2
% https://cosmiic.atlassian.net/wiki/pages/viewpageattachments.action?pageId=11535248&preview=%2F11535248%2F11541107%2FRadio%20Implementation%20for%20MedRadio%20Compliance.pptx
%% enable encryption 
% enable encryption on PM
nnp.nmt(7, 'BA', 1)
% enable encryption on AP
nnp.transmitAP(hex2dec('4f'), 1)

%% disable encryption 
% disable encryption on PM
nnp.nmt(7, 'BA', 0)
% disable encryption on AP
nnp.transmitAP(hex2dec('4f'), 0)
% Set Session Time 
nnp.transmitAP(0x4C, 5)

%% enable MedRadio
% Enable MedRadio on PM with default Session Time (5s)
nnp.write(7,'2600', 14, 5)
% Enable MedRadio on WL with default Session Time (5s)
nnp.transmitAP(0x4C, 5)

%% disable MedRadio
% Disable MedRadio on PM
nnp.write(7,'2600', 14, 0)
% Disable MedRadio on WL
nnp.transmitAP(0x4C, 0)
%Set channel manually
nnp.setRadio('chan', 5)

%% Set WL to use Minimum Dwell time (10ms) when looking for quietest channel
resp = nnp.transmitAP(0x4B, 1);
if length(resp)==21
    d = typecast(resp(2:end), 'int8');
    maxRSSI = d(1:10)
    avgRSSI = d(11:20)
end

%% Maintain session Automatically
nnp.transmitAP(0x4E, 1)
%% Don't maintain session
nnp.transmitAP(0x4E, 0)
%% Timing 
% Assume WOR is enabled
% Assume Session = 5, Maintain is disabled
% Assume not in session
tic
nnp.getSerial
toc
% expect around 0.4s
% call this section again within 5s, and response should be about 0.04s
% Wait at least 5s 
% call this section again, expect around 0.4s
% Next enable Maintain
% first call expect around 0.4s
% all remaining calls expect arounf 0.04s even if waiting more than 5s 


%% Maximum Dwell while sessionTime = 0
% This is the maximum time that you can sample each channel to listen if session=0
tic
t = nnp.timeout;
nnp.timeout = 30; %255*10ms*10ch = 25.5 s minimum
nnp.setRadio('chan', 0); resp = nnp.transmitAP(0x4B, 255);
if length(resp)==21
    d = typecast(resp(2:end), 'int8');
    maxRSSI = d(1:10)
    avgRSSI = d(11:20)
end
nnp.timeout = t; 
toc

%% Maximum Dwell while sessionTime = 5
% this can help you determine what channels other radio in your vicinity are operating on
% If the dwell is set to 255, and the sessiontime > 0, then the maximum dwell per channel is the session time
tic
t = nnp.timeout;
nnp.timeout = 60; %5s*10ch = 25.5 s minimum
nnp.setRadio('chan', 0); resp = nnp.transmitAP(0x4B, 255);
if length(resp)==21
    d = typecast(resp(2:end), 'int8');
    maxRSSI = d(1:10)
    avgRSSI = d(11:20)
end
nnp.timeout = t; 
toc

%% Get Session Time Left 
% Time remaining in session from WL (in ms)
% If Maintain is enabled, this will count down from 5000 and then start back over
resp = nnp.transmitAP(0x4D);
if length(resp)==2
    t = double(typecast(resp, 'uint16'))
end

%% Get PM session time
%if nonzero, session is enabled.  Should be <=5 for MedRAdio compliance
nnp.read(7,'2600', 14, 1)
