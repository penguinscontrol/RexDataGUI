function [alignedrasters, alignindex, trialindex, alltrigtosac, ...
    allsactotrig, alltrigtovis, allvistotrig,eyehoriz, eyevert, ....
    eyevelocity, amplitudes, peakvels,...
    peakaccs, allonoffcodetime,badidx,allssd] = ...
    rdd_rasters( name, spikechannel, aligntocode, noneofcodes,...
    allowbadtrials, alignsacnum, aligntype, collapse, conditions)

% used to be: rdd_rasters( name, spikechannel, anyofcodes, allofcodes, noneofcodes, alignmentcode, allowbadtrials, alignsacnum, oncode, offcode)


%  [alignedrasters, alignindex, eyeh, eyev, eyevel, allonofftime, trialnumbers] = rex_rasters_trialtype
%      ( name, binwidth, anyofcodes, allofcodes, noneofcodes, alignmentcode, allowbadtrials, alignsacnum, oncode, offcode)
%
%  Called by rdd_rasters_sdf to compile data about trial classes from Rex data.
%  Generates spike rasters
%
%  Allows selection of trials that only contain certain codes, and allows
%  alignment on those or other codes.  'alignindex' returns the index in the
%  rasters (the column, assuming each row is a raster) at which all rasters
%  are aligned, given the alignmentcode.  This should be 1 if no alignment
%  codes are used.  It will > 1 if the alignment code did not occur at the
%  same place in each trial and rasters had to be shifted in order to
%  align them all.  Also returns some eye information that will be described
%  later ( horizontal,  vertical, and  velocity of eye traces).  The last
%  return value is a list of trial numbers corresponding to the trials
%  gathered with the requested codes.
%
%  name - of the converted Rex data file (without the '.mat')
%  spikechannel - which spike channel to get data from.  Usually this is 1,
%       and in fact right now the code ignores this and uses 1.
%  anyofcodes, allofcodes, noneofcodes - the codes that indicate what trials
%       to look for.  Can be empty, can
%       be a single value, or a list of values [6022 6027 6087] and so on.
%  alignmentcode - optional.  What code in each trial is the data to be
%       aligned to (can also be a list).  Aligns to the first match it
%       finds.  If left off, the trialcodevalues are used for alignment.
%  allowbadtrials - 1 if bad trials should be included in the analysis.
%  alignsacnum - optional.  This is used to align the results to the
%       n-th saccade following the alignment code, where n is alignsacnum.
%
%  Currently this code assumes only one set of spikes is coming out of
%  rex_trial (in spk).  This will not always be right if there are
%  multiple channels (units, whatever) in the Rex file.
%
%  EXAMPLE:
%     [r,aidx] = rex_rasters_trialtype( filename, 1, anyofthese, [],[],aligncodes);
%     %  Summate all the rasters for PETH-type things
%     sumall = merge_raster( r );
%     %  Calculating spike density
%     sdf = spike_density( sumall, 5 );
%     %  Calculating probability density
%     pdf = probability_density( sumall, 5 );
%     start = aidx - 500;
%     stop = aidx + 500;
%     plot( sdf( start:stop) ); % plot spike density for 500 ms before
%                               % to 500 ms after the time of the alignment

%global allonofftime;
%global trialonofftime;
global rexnumtrials;

tasktype=get(findobj('Tag','taskdisplay'),'String');
[~, ~, tgtcode, tgtoffcode] = taskfindecode(tasktype);
alignedrasters=[];
sphisto=[];
alignindex=[];
trialindex=[];
trigtosac=[];
sactotrig=[];
trigtovis=[];
vistotrig=[];
eyehoriz=[];
eyevert=[];
eyevelocity=[];
trialnumbers=[];
%oldallonoffcodetime=[];
amplitudes=[];
peakvels=[];
peakaccs=[];
alignto = aligntocode;
sacamp = NaN;
sacpeakpeakvel = NaN;
sacpeakacc = NaN;

sbad = '';
if ~allowbadtrials
    sbad = 'Bad trials skipped: ';
end;

% Variables that will be incremented or appended as matching trials are
% collected.

alignmentfound = 0;
nummatch = 0;
alignindexlist = [];
rasters = [];
eyeh = [];
eyev = [];
eyevel = [];
eyehoriz = [];
eyevert = [];
eyevelocity = [];
allonoffcodetime = [];
onoffcodetime=[];
alltrigtosac=[];
allsactotrig=[];
alltrigtovis=[];
allvistotrig=[];
badidx=[];
allssd=[];
% allcondtime = [];

%  Loop through all of the trials using rex_first_trial and rex_next_trial.
%  See if each trial has the right codes, and try to align the spike data
%  to one of the alignment codes.

d = rex_first_trial( name, rexnumtrials, allowbadtrials );
islast = (d == 0);
while ~islast
    
    % For the current trial given by 'd', a call to rex_trial
    % gives us the codes, their times, the spike data, the
    % sampling rate, and the horizontal and vertical eye traces.  It also
    % gives start_time relative to the start of the whole file, and a
    % badtrial flag, which is irrelevant since we already know if this will
    % be a valid trial or not (because of the 2nd parameter in
    % rex_first_trial and rex_next_trial).
    
    %[ecodeout, etimeout, spkchan, spk, arate, h, v, start_time, badtrial ] = rex_trial(name, d );
    
    [ecodeout, etimeout, spkchan, spk, arate, h, v, start_time, isbadtrial, curtrialsacInfo] = rdd_rex_trial(name, d);%, rdt_includeaborted);
    
    %if ~isbadtrial
    	if logical(sum((ecodeout==2222)))  % had a weird case of a trial with ecode 2222. Don't know what that was. See file S110L4A5_12951
            ecodeout(find(ecodeout==1035))=17385; % replace 1035 code by error code, to false positive on 1030
            isbadtrial=1;
        end
    %end
    %curdir=ecodeout(2)-floor(ecodeout(2)/10)*10;
    
%     if strcmp(tasktype,'gapstop') || strcmp(tasktype,'base2rem50')
%         multicode=1;
%     else
%         multicode=0;
%     end
%     

    if isempty(h) || isempty(ecodeout)
        cond_disp( 'Something wrong with trial, no data.' );
    else
        if  collapse %for collapsed alignements
%             || multicode
            anyof = has_any_of( ecodeout, alignto );
            allof = 1;
        else
            allof = has_all_of( ecodeout, alignto );
            anyof=1;
        end
    if logical(sum(find(noneofcodes==alignto(1)))) ... %in case the purpose IS to align to a noneof code
            || allowbadtrials % or if we want the bad trials too
        noneof = 1;
        isbadtrial=~has_none_of(ecodeout, noneofcodes); %make sure trials with noneofcodes other than 17385 are tagged is bad
    else
        noneof = has_none_of( ecodeout, noneofcodes );
    end
        
        %  If these are all true, we have found a trial matching the
        %  requested codes.  Now check for alignment, which might be a
        %  whole list of possible candidates.  This actually makes a list
        %  (falign) of the ecode indices where there's a match, which is
        %  probably unneccessary, since only the first is used.
        
        if allof & noneof & anyof
            falign = [];
            for i = 1:length( alignto )
                fnext = find( ecodeout == alignto(i) );
                if ~isempty( fnext )
                    if isempty( falign )
                        falign = fnext(1);
                    else
                        falign = [falign;fnext(1)];
                    end;
                end;
            end;
            
            if isempty( falign )
                s = sprintf( 'In rdd_rasters, trial %d has a matching base code (%d?), but does not contain any alignment code requested.', d, ecodeout(2) );
                cond_disp( s );
            else
                %% getting align times
                % We found one or more alignments, so get the actual time of the
                % first one. (we only want to align on the first one: make sure it's the right one passed as argument)
                
                alignmentfound = ecodeout( falign(1) );
                aligntime = etimeout( falign( 1 ) ) * (arate / 1000);
                
                % get the alignment type. If it's a saccade align code, replace aligntime with the
                % actual sac start (with new sac detection method:
%                 ATPbuttonnb=find(strcmp(get(get(findobj('Tag','aligntimepanel'),'SelectedObject'),'Tag'), ...
%                     get(findall(findobj('Tag','aligntimepanel')),'Tag')));

                if  strcmp(aligntype,'sac') || strcmp(aligntype,'corsac') ...
                        || strcmp(aligntype,'error2')% mainsacalign button OR corrective saccade
                    ampsacofint=[];
                    nwsacstart=cat(1,curtrialsacInfo.starttime);
                    if strcmp(tasktype,'tokens')
                        if strcmp(aligntype,'error2')
                            sacofint=nwsacstart>etimeout(falign(1)-2); % finding saccades occuring
                                                                       % between the last token and
                                                                       %the detected saccade (to the wrong target)
                        else
                        sacofint=nwsacstart>etimeout(falign(1))-40;  % the token task is special
                        % in that we do not detect the saccade itself, but the eye leaving
                        % the fixation window. The small delay (40ms) reflects that
                        end
                    else
                        sacofint=nwsacstart>etimeout(falign(1)-1); %considering all saccades occuring after the ecode
                                                                %preceding the saccade ecode, which is often erroneous
                    end
                     if strcmp(tasktype,'st_saccades')  
                               if nwsacstart(find(sacofint,1))-etimeout(7)<600 %there was a saccade during the delay period that went unnoticed by Rex saccade detection 
                                   if abs(curtrialsacInfo(find(sacofint,1)).amplitude)>2 % keeping trials with saccades under 2 degrees, which happens pretty frequently with Sixx. 
                                   sacofint=0;
                                   alignmentfound = 0;
                                   end
                               end
                     end
                    for k=find(sacofint,1):length(sacofint)
                        ampsacofint(1,k)=abs(getfield(curtrialsacInfo, {k}, 'amplitude'));
                    end
                    %start time of first saccade greater than 3 degrees (typical
                    %restriction window) after relevant ecode (ecodesacstart-1)
                    if ~logical(sum(ampsacofint))
                        alignmentfound = 0;
                    elseif logical(sum(ampsacofint>3))
                        if strcmp(aligntype,'sac') || strcmp(aligntype,'error2') 
                            aligntime=getfield(curtrialsacInfo, {find(ampsacofint>3,1)}, 'starttime');
                            sacamp=getfield(curtrialsacInfo, {find(ampsacofint>3,1)}, 'amplitude');
                            sacpeakpeakvel=getfield(curtrialsacInfo, {find(ampsacofint>3,1)}, 'peakVelocity');
                            sacpeakacc=getfield(curtrialsacInfo, {find(ampsacofint>3,1)}, 'peakAcceleration');
                        elseif alignsacnum && length(ampsacofint>3)>= 2  % If we are looking for the n-th saccade after our found
                            % alignment,
                            nextgoodsac=find(ampsacofint>3,2);
                            aligntime=getfield(curtrialsacInfo, {nextgoodsac(2)}, 'starttime');
                            sacamp=getfield(curtrialsacInfo, {nextgoodsac(2)}, 'amplitude');
                            sacpeakpeakvel=getfield(curtrialsacInfo, {nextgoodsac(2)}, 'peakVelocity');
                            sacpeakacc=getfield(curtrialsacInfo, {nextgoodsac(2)}, 'peakAcceleration');
                        elseif alignsacnum && length(ampsacofint>3)< 2 % no good n-th saccade
                            alignmentfound = 0;
                        end
                    end
                end
                if strcmp(aligntype,'stop')
                        if ecodeout(9)==17385 || ecodeout(9)==16386
                             ampsacofint=[];
                             nwsacstart=cat(1,curtrialsacInfo.starttime);
                             sacofint=nwsacstart>etimeout(falign(1));
                             if sum(sacofint)
                                  aligntime=getfield(curtrialsacInfo, {find(sacofint,1)}, 'starttime');
                             else
                                  alignmentfound = 0;
                             end
                        end
                 end
                
                %% now get the time of "grey area" ecodes
                % used to get only times for selected conditions. Now get
                % all, and just displaying the requested ones in
                % rdd_rasters_sdf. VP 7/14/2012
                %selectedgrey=find([get(findobj('Tag','greycue'),'Value'),get(findobj('Tag','greyemvt'),'Value'),get(findobj('Tag','greyfix'),'Value')]);
                
                
                greytypes={'cue';'eyemvt';'fix'};
                
                    %caveat: some conditions may be 4 or 5 digits long,
                    %such as user defined codes such as TOKSWCD (1501) 
                    
                    conditions(conditions>=1000)=floor(conditions(conditions>=1000)/10); %cut last digit off of them
                
%                 greytypes=(greytypes(selectedgrey));
                codepairnb=floor(size(conditions,2)/2);%there may be multiple code. See l. 421 as well as here (273)
  %              if logical(sum(greycodes))
                shortecodout=floor(ecodeout./10);
%                     if size(greycodes,1)>1 %more than one row: means several checkboxes are selected
                        for i=1:size(conditions,1)
                            goodsacnum=0;
                            if strcmp(greytypes(i),'eyemvt') %adjust times to real saccade times
                                % find which saccade is the "good" one (if any) in this trial
                                try goodsacnum=find(~cellfun(@isempty,{curtrialsacInfo.latency}));  catch goodsacnum=0; end 
                                if ~logical(sum(goodsacnum)) && ~strcmp(aligntype,'stop')
                                    s = sprintf('cannot display grey area for trial %d because saccade cannot be found. Removing erroneous trial',d);
                                    disp(s);
                                    alignmentfound = 0;
                                end
                            end
                                for j=1:size(conditions,2)
                                    try fonoffcode(i,j) = find(shortecodout == conditions(i,j),1);  catch fonoffcode(i,j) = NaN; end %in multiple code tasks (eg, gapstop), may fail to find the code in the ecode list
                                    try onoffcodetime(i,j) = etimeout(fonoffcode(i,j)) * (arate / 1000); catch onoffcodetime(i,j) = NaN; end
                                end
                                if logical(goodsacnum)
                                    onoffcodetime(i,1)=getfield(curtrialsacInfo, {goodsacnum}, 'starttime');
                                    onoffcodetime(i,1+codepairnb)=getfield(curtrialsacInfo, {goodsacnum}, 'endtime');
                                end  
                        end
%                     else % if only one conition selected
%                         goodsacnum=0;
%                         if strcmp(greytypes,'eyemvt') %adjust times to real saccade times
%                                 % find which saccade is the "good" one (if any) in this trial
%                         try goodsacnum=find(~cellfun(@isempty,{curtrialsacInfo.latency}));   catch goodsacnum=0; end                             
%                         end
%                             for j=1:size(greycodes,2)
%                                 try fonoffcode(j) = find( shortecodout == greycodes(j),1); catch fonoffcode(j) = NaN; end
%                                 try onoffcodetime(j) = etimeout(fonoffcode(j)) * (arate / 1000); catch onoffcodetime(j) = NaN; end
%                             end
%                                if logical(goodsacnum)
%                                     onoffcodetime(1)=getfield(curtrialsacInfo, {goodsacnum}, 'starttime');
%                                     onoffcodetime(1+codepairnb)=getfield(curtrialsacInfo, {goodsacnum}, 'endtime');
%                                 end  
%                     end
  %              end
                
                %% find condition times 
%                 codepairnb=floor(size(conditions,2)/2);%there may be multiple code. See l. 421 as well as here (273)
%                 shortecodout=floor(ecodeout./10);
%                 for i=1:size(conditions,1)
% 
%                     for j=1:size(conditions,2)
%                         try fcondcode(i,j) = find(shortecodout == conditions(i,j),1);  catch fcondcode(i,j) = NaN; end %in multiple code tasks (ie, gapstop), may fail to find the code in the ecode list
%                         try condcodetime(i,j) = etimeout(fcondcode(i,j)) * (arate / 1000); catch condcodetime(i,j) = NaN; end
%                     end
% 
%                 end
%                 
%                 condmattime = {condcodetime};
%                 
                %% filling up alignindexlist with align times
                %                if alignsacnum == 0
                
                if alignmentfound
                    nummatch = nummatch + 1;
                    alignindexlist( nummatch ) = aligntime;
                    trialindex(nummatch)=d;
                    badidx(nummatch)=isbadtrial;
                    if strcmp(aligntype,'stop')
                        if ecodeout(9)==17385 || ecodeout(9)==16386
                             badidx(nummatch)=2; %non-cancelled trials
                        end
                        if ecodeout(8)==1503 %with photodiode state timestamp
                            allssd(nummatch,1)=etimeout(:,9)-etimeout(:,7);
                            allssd(nummatch,2)=etimeout(:,8)-etimeout(:,7);
                        else
                            allssd(nummatch)=etimeout(:,8)-etimeout(:,7);
                        end
                    end
                                        
                    % trigger times
                    if (tgtcode<=1000)
                        ecodeson=shortecodout;
                    else
                        ecodeson=ecodeout;
                    end
                    if (tgtoffcode<=1000)
                        ecodesoff=shortecodout;
                    else
                        ecodesoff=ecodeout;
                    end
                        visevents=[etimeout(ismember(ecodeson,tgtcode)), etimeout(ismember(ecodesoff,tgtoffcode))]-etimeout(1)-1;

                    % recordings with trigger channel
                    if find(ecodeout==1502) % Trigger code
%                         triggercode=1;
                        trigtosac=aligntime-etimeout(1)-1; %trigger code is 1ms before 1001                    
                        trigtovis=max(visevents(visevents<trigtosac)); %the latest visual event occuring before alignment time
                        if find(ecodeout==1030)
                            sactotrig=etimeout(find(ecodeout==1502,1))+1-aligntime; %the second trigger channel is actually the start of the next trial
                            vistotrig=etimeout(find(ecodeout==1502,1))+1-max(visevents(visevents<trigtosac)+etimeout(1)+1);
                        else
                            sactotrig=NaN;
                            vistotrig=NaN;
                        end
                        
                    else %older recordings without trigger code
%                         triggercode=0;
                        trigtosac=aligntime-etimeout(1)-1; %in case there is a trigger channel available in the SH recording
                        trigtovis=max(visevents(visevents<trigtosac)); %the latest visual event occuring before alignment time
                        if find(ecodeout==1030) %good trial
                            sactotrig=etimeout(find(ecodeout==1030,1))+1-aligntime;%1ms between reward code and valve opening
                            vistotrig=etimeout(find(ecodeout==1030,1))+1-max(visevents(visevents<trigtosac)+etimeout(1)+1);
                        else %wrong trial
                            sactotrig=NaN;
                            vistotrig=NaN;
                        end
                        if sactotrig<0
                            ecodeout;
                        end
                    end
                    
                end
                %                 elseif alignsacnum < 0
                %                     cond_disp( 'In rdd_rasters, aligning to saccades BEFORE alignment codes has not been implemented yet. ');
                %                     alignmentfound = 0;
                %                 elseif alignsacnum > 0
                %                     [sstarts, sends] = rex_trial_saccade_times( name, d );
                %                     sacnumstart = find( sstarts > aligntime );
                %                     if length( sacnumstart ) < alignsacnum
                %                         alignmentfound = 0;
                %                     else
                %                         aligntime = sstarts( sacnumstart(alignsacnum) );
                %                         nummatch = nummatch + 1;
                %                         alignindexlist( nummatch ) = aligntime;
                %                     end;
                %                 end;
                
                %% Collecting spikes and stuff
                % If we found a place to align, either a code, or a code
                % followed by the alignsacnum-th saccade, then collect the
                % spikes for this trial in 'train', and then add to the
                % raster list of all spike trains so far, i.e. 'rasters'.
                % Though added to the rasters list, these trains are not
                % yet aligned.  That happens later.
                
                if alignmentfound
                    trialnumbers(nummatch)=d;
                    amplitudes(nummatch)=sacamp;
                    peakvels(nummatch)=sacpeakpeakvel;
                    peakaccs(nummatch)=sacpeakacc;
                    train = [0];
                    if ~isempty( spk )
                        [train, last] = rex_spk2raster( spk, 1, length( h ) );
                        if isempty(train)
                            train=nan(1,length(h));
                            last=length(h);
                        end
                    end;
                    rasters = cat_variable_size_row( rasters, train );
                    %collect conditions (aka greycodes) times
%                     trialonofftime=zeros(1,length(h));
%                     for i=size(conditions,1):-1:1
%                     onoffkeepcode=[onoffcodetime(i,find(~isnan(onoffcodetime(i,:)),1))...
%                                     onoffcodetime(i,find(~isnan(onoffcodetime(i,:)),1)+codepairnb)];
%                     trialonofftime(onoffkeepcode(1):onoffkeepcode(2))=i;
%                     end
%                     oldallonoffcodetime=cat_variable_size_row(oldallonoffcodetime, trialonofftime);
                    if  ~(size(onoffcodetime,2)==2 && codepairnb==1)
                    onoffkeepcode=[find(~isnan(onoffcodetime(1,:)),1) find(~isnan(onoffcodetime(1,:)),1)+codepairnb];
                    onoffcodetime=onoffcodetime(:,onoffkeepcode);
                    end
                    allonoffcodetime=[allonoffcodetime {onoffcodetime}];
                    
                    %and collect trigger alignments
                    alltrigtosac=[alltrigtosac trigtosac];
                    allsactotrig=[allsactotrig sactotrig]; 
                    alltrigtovis=[alltrigtovis trigtovis];
                    allvistotrig=[allvistotrig vistotrig]; 
                    
                    
                    if length(h)<length(train)
                        s = sprintf( 'In rdd_rasters, the eye trace was shorter than the spike raster (%d < %d) for trial %d.  Padding with zeros.',...
                            length(h), length(train), d );
                        %cond_disp(s);
                        h = [h zeros(1, length(train)-length(h))];
                        v = [v zeros(1, length(train)-length(v))];
                    end;
                    
                    % Also collect eye movement traces for this trial, and
                    % add to the lists (eyeh and eyev).  Also do velocity.
                    
                    eyeh = cat_variable_size_row( eyeh, h );
                    eyev = cat_variable_size_row( eyev, v );
                    %                     dh = diff( h );
                    %                     dv = diff( v );
                    %                     velocity = sqrt( ( dh .* dh ) + ( dv .* dv ) );
                    [filth, filtv, filtvel]=cal_velacc(h,v);
                    eyevel = cat_variable_size_row( eyevel, filtvel);
                    
                    
%                     if logical(sum(greycodes))
%                         trialonofftime=zeros(1,length(h));
%                         if size(greycodes,1)>1 %more than one row
%                             for i=1:size(conditions,1)
%                                 onoffkeepcode=[onoffcodetime(i,find(~isnan(onoffcodetime(i,:)),1))...
%                                     onoffcodetime(i,find(~isnan(onoffcodetime(i,:)),1)+codepairnb)]; %keep the first pair of good codes
%                                trialonofftime(onoffkeepcode(1):onoffkeepcode(2))=i; % a bit ridiculous, but simpler than keeping indexes in this code
%                             end
%                         else
%                             onoffkeepcode=[onoffcodetime(1,find(~isnan(onoffcodetime(1,:)),1))...
%                             onoffcodetime(1,find(~isnan(onoffcodetime(1,:)),1)+codepairnb)]; %keep the first pair of good codes
%                             trialonofftime(onoffkeepcode(1):onoffkeepcode(2))=1;
%                         end
% 
%                         allonoffcodetime=cat_variable_size_row(allonoffcodetime, trialonofftime);
%                     end
                    
                    % collect condition times
%                     allcondtime = cat_variable_size_row(allcondtime, condmattime);
                    

                end;
            end;
        end;
    end;
    
    [d, islast] = rex_next_trial( name, d, allowbadtrials );
    
end;


if isempty( rasters )
    cond_disp( 'rdd_rasters: Cannot generate rasters with the given codes, since no matching trials were found.' );
    alignedrasters = [];
    alignindex = 0;
    sphisto = [];
    return;
end;

% We have rows of spike trains (rasters), and indices on which to align
% them (alignindexlist).  Now shift, or align, each of the rows so that the
% alignment time occurs at the same index in all rows.  See
% align_rows_on_indices() to see how this works.
alignindex = max( alignindexlist );

% alignindex is now the index (the column) in alignedrasters that is the
% column to which all rows are aligned. 
[alignedrasters,shift] = align_rows_on_indices( rasters, alignindexlist );

%Do the same for the eye stuff.
eyehoriz = align_rows_on_indices( eyeh, alignindexlist );
eyevert = align_rows_on_indices( eyev, alignindexlist );
eyevelocity = align_rows_on_indices( eyevel, alignindexlist );

%add shift to grey areas times
for shifttm=1:size(shift,1)
allonoffcodetime(shifttm)={cell2mat(allonoffcodetime(shifttm))+shift(shifttm)};
end
% cell2mat(allonoffcodetime(1))
% cell2mat(allonoffcodetime(1))+shift(1)
% 
% foo = align_rows_on_indices(oldallonoffcodetime, alignindexlist );
%     find(oldallonoffcodetime(1,:),1)
%     find(foo(1,:),1)

end

% figure( 21 )
% subplot( 2, 1, 1 );
% imagesc( rasters );
% subplot( 2, 1, 2 );
% imagesc( alignedrasters );
% colormap( 1 - GRAY );
% alignindex
% alignindexlist

%same treatment for the on/off ecodes time
% if logical(sum(conditions))
%     allonofftime = align_rows_on_indices(allonoffcodetime, alignindexlist );
% else
%     allonofftime = [];
% end



% Done.  Everything is collected and aligned for all matching trials.

