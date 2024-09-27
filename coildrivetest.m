nnp = NNPCHARGER()
%%
nnp.setChargerVoltage(7)
%%
nnp.startCoil;
%%

N=60;
data = nan(N, 3);


for i=1:N
    current = nnp.getChargerCurrent;
    if isempty(current)
        current = NaN;
    end
    temp1 = nnp.getCoilTemp1;
    if isempty(temp1)
        temp1 = NaN;
    end
    temp2 = nnp.getCoilTemp2;
    if isempty(temp2)
        temp2 = NaN;
    end
    temp3 = nnp.getChargerTemp;
    if isempty(temp3)
        temp3 = NaN;
    end
    pause(1)
    fprintf('\nCurrent %5.2f mA, Temps %5.2f deg, %5.2f deg, %5.2f deg', current, temp1, temp2, temp3) 
    data(i,:) = [current, temp1, temp2];
end



