/****** Object:  StoredProcedure [dbo].[CSP_CDMSUITE_ReserveDrawingNumbers]    Script Date: 11/1/2017 4:03:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Antoine Ibrahim
-- Description:	Will reserve drawing numbers
-- =============================================
ALTER PROCEDURE [dbo].[CSP_CDMSUITE_ReserveDrawingNumbers]
	@Request_List NVARCHAR(MAX),  -- Must be in the format 'prefix:quantity:suffix;prefix:quantity:suffix'
	@RequestID  BIGINT,
	@RequestType NVARCHAR(255),
    @UserName NVARCHAR(255),
	@NewRequest BIT,
	@IsCdmUser BIT,
	@RequestData NVARCHAR(MAX)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

-- examples of 
--DECLARE @Request_List nvarchar(max) ='5:5:NULL;2:1:NULL;5:3:NULL;7:3:NULL;4:4:NULL;';
--DECLARE @Request_List nvarchar(max) ='Tony Sub1 1/L:1:NULL;Tony Sub2 1/L:1:NULL;Tony Sub3 1/L:1:NULL;';
--DECLARE @Request_List nvarchar(max) ='ShOrSect1:1:SEC 1 BK 1;ShOrSect2:1:SEC 2 BK 2;ShOrSect3:1:SEC 3 BK 3;';
--DECLARE @Request_List nvarchar(max)='5:52:NULL;'
	
DECLARE 
	@one_LastGenID BIGINT = 0,
	@two_LastGenID BIGINT = 0,
	@four_LastGenID BIGINT = 0,
	@five_LastGenID BIGINT = 0,
	@seven_LastGenID BIGINT = 0,
	@m_LastGenID BIGINT = 0,
	@dc_LastGenID BIGINT = 0,
	@n_LastGenID BIGINT = 0,
	@nextAdnID BIGINT = 0,
	@countOfNextAdn BIT = 0,
	@endOfLowRange BIGINT = 0,
	@startOfHighRange BIGINT = 0,
	@reserved_numbers NVARCHAR(MAX) = '',
	@quantity NVARCHAR(255) = '0',
	@qty BIGINT = 0,
	@prefix NVARCHAR(255),
	@suffix NVARCHAR(255),
	@counter INT = 0,
	@wholeid NVARCHAR(MAX) = '',
	@seqid BIGINT = 0,
	@startSeq NVARCHAR(MAX) = '',
	@trackedNums NVARCHAR(MAX) = '',
	@alreadyGenerated BIT = 0,
	@returnMessage NVARCHAR(MAX) = '',
	@existsInAdnIds INT = 0;


IF (@NewRequest=1) -- if it is a brand new request
BEGIN
	IF(@IsCdmUser=0) -- if it is not a cdm user, just input the 
	BEGIN
	
		INSERT INTO C_CDMSUITE_DrawingRequest (RequestType, RequestedBy,RequestDate,ProcessedStatus, RequestData)
				VALUES(@RequestType, @UserName, SYSDATETIME(), 'U', @RequestData);

		SET @RequestID= (SELECT MAX(requestid) FROM C_CDMSUITE_DrawingRequest WHERE RequestedBy=@UserName AND ProcessedStatus='U');
	END;

	 IF(@IsCdmUser=1)
	 BEGIN
		INSERT INTO C_CDMSUITE_DrawingRequest (RequestType,RequestedBy, RequestDate, ProcessedBy,  ProcessedStatus,  ProcessedDate, RequestData)
			   VALUES (@RequestType, @UserName,SYSDATETIME(),  @UserName, 'P', SYSDATETIME(), @RequestData);
		SET @RequestID= (SELECT MAX(requestid) FROM C_CDMSUITE_DrawingRequest WHERE ProcessedBy=@UserName AND ProcessedStatus='P');
	 END;
END;


SET @alreadyGenerated =  (SELECT CASE WHEN ReservedNumbers IS NOT NULL THEN 1 ELSE 0 END FROM C_CDMSUITE_DrawingRequest WHERE requestid=@RequestID );
IF @alreadyGenerated IS NULL
BEGIN
	SET @alreadyGenerated=0;
END;

-- if the drawings are not generated and the user is a cdm user, reserve the numbers
IF (@alreadyGenerated=0 AND @IsCdmUser=1)
BEGIN
	BEGIN TRANSACTION; 

	SET @one_LastGenID= (SELECT MAX(seqid) FROM adnids WHERE adnType='CDM:SCE Drawing' AND PREFIX='1');
	SET @two_LastGenID= (SELECT MAX(seqid) FROM adnids WHERE adnType='CDM:SCE Drawing' AND PREFIX='2');
	SET @four_LastGenID= (SELECT MAX(seqid) FROM adnids WHERE adnType='CDM:SCE Drawing' AND PREFIX='4');
	SET @five_LastGenID= (SELECT MAX(seqid) FROM adnids WHERE adnType='CDM:SCE Drawing' AND PREFIX='5');
	SET @seven_LastGenID= (SELECT MAX(seqid) FROM adnids WHERE adnType='CDM:SCE Drawing' AND PREFIX='7');
	SET @m_LastGenID= (SELECT MAX(seqid) FROM adnids WHERE adnType='CDM:SCE Drawing' AND PREFIX='M');
	SET @n_LastGenID= (SELECT MAX(seqid) FROM adnids WHERE adnType='CDM:SCE Drawing' AND PREFIX='N');
	SET @dc_LastGenID= (SELECT MAX(seqid) FROM adnids WHERE adnType='CDM:SCE Drawing' AND PREFIX='DC');
	SELECT @nextAdnID= currentid , @endOfLowRange =endOfLowRange, @startOfHighRange=startOfHighRange FROM c_CDMSUITE_ReservedADNIDs;

	-- itterate through each line item in the list 
	WHILE @Request_List !=''
		BEGIN
			SELECT @prefix	= SUBSTRING(@Request_List, 0, CHARINDEX(':', @Request_List));
			SELECT @Request_List= SUBSTRING(@Request_List, CHARINDEX(':', @Request_List)+1, LEN(@Request_List));
			
			SELECT @quantity	= SUBSTRING(@Request_List, 0, CHARINDEX(':', @Request_List));
			SELECT @Request_List= SUBSTRING(@Request_List, CHARINDEX(':', @Request_List)+1, LEN(@Request_List));

			SELECT @suffix		= SUBSTRING(@Request_List, 0, CHARINDEX(';', @Request_List));
			SELECT @Request_List= SUBSTRING(@Request_List, CHARINDEX(';', @Request_List)+1, LEN(@Request_List));
			SET @qty = CAST(@quantity AS BIGINT);

			--PRINT 'Prefix:'+@prefix;
			--PRINT 'qtantity:'+@quantity; 
			--PRINT 'qty:'+CAST(@qty AS VARCHAR(20)); 
			--PRINT 'suffix:'+@suffix; 
			--PRINT 'Remaining: '+@Request_List; 
			SET @counter =0;   
			SET @startSeq = '';

			-- for each line item generate the quantity needed 
			WHILE @counter<@qty
				BEGIN
				--PRINT CAST(@counter AS VARCHAR(20)); 
				-- reset the whole id 
					SET @wholeid  = '';

					-- checks if the next adn id is available, it then finds the next agailable one, if it hits the max number
					-- it will jump to the start of high range 
					SET @countOfNextAdn =1;
					WHILE @countOfNextAdn >0
					BEGIN 
						IF @nextAdnID = @endOfLowRange 
						BEGIN
							SET @nextAdnID =@startOfHighRange;
						END;

						SELECT @countOfNextAdn =COUNT(ADNID) FROM AdnIDs WHERE ADNID=@nextAdnID;
						IF @countOfNextAdn>0
						BEGIN 
							SET @nextAdnID +=1;
						END;
					END;

					-- if the prefix is one of the below strings

					IF @prefix IN('1','2','4','5','7','M','N','DC')
					BEGIN 
						IF @prefix='1'
						BEGIN
							SET @one_LastGenID +=1;
							SET @seqid=@one_LastGenID;
							SET @wholeid=@prefix +CAST (@one_LastGenID AS NVARCHAR(20));
						END;
						IF @prefix='2'
						BEGIN
							SET @two_LastGenID +=1;
							SET @seqid=@two_LastGenID;
							SET @wholeid=@prefix +CAST (@two_LastGenID AS NVARCHAR(20));
						END;
						IF @prefix='4'
						BEGIN
							SET @four_LastGenID +=1;
							SET @seqid=@four_LastGenID;
							SET @wholeid=@prefix +CAST (@four_LastGenID AS NVARCHAR(20));
						END;
						IF @prefix='5'
						BEGIN
							SET @five_LastGenID +=1;
							SET @seqid=@five_LastGenID;
							SET @wholeid=@prefix +CAST (@five_LastGenID AS NVARCHAR(20));
						END;
						IF @prefix='7'
						BEGIN
							SET @seven_LastGenID +=1;
							SET @seqid=@seven_LastGenID;
							SET @wholeid=@prefix +CAST (@seven_LastGenID AS NVARCHAR(20));
						END;
						IF @prefix='M'
						BEGIN
							SET @m_LastGenID +=1;
							SET @seqid=@m_LastGenID;
							SET @wholeid=@prefix +CAST (@m_LastGenID AS NVARCHAR(20));
						END;
						IF @prefix='N'
						BEGIN
							SET @n_LastGenID +=1;
							SET @seqid=@n_LastGenID;
							SET @wholeid=@prefix +CAST (@n_LastGenID AS NVARCHAR(20));
						END;
						IF @prefix='DC'
						BEGIN
							SET @dc_LastGenID +=1;
							SET @seqid=@dc_LastGenID;
							SET @wholeid=@prefix +CAST (@dc_LastGenID AS NVARCHAR(20));
						END;
						-- get the starting sequence of the range of drawing numbers
						IF @startSeq = ''
						BEGIN
							SET @startSeq= @prefix+':'+CAST (@seqid AS NVARCHAR(20));
						END;
					END;

				-- if the suffix is null then make it an empty strin
					ELSE IF @suffix='NULL'
					BEGIN
						--set @suffix=null
						SET @seqid=0;
						SET @wholeid=@prefix; 
					END;

					ELSE IF @suffix !='NULL'
					BEGIN
						SET @seqid=0;
						SET @wholeid=@prefix +' '+ @suffix;
					END;
					--PRINT 'need to insert adnid'+CAST (@nextAdnID AS VARCHAR(20))+'Seqid: '+CAST (@seqid AS VARCHAR(20)) + ' wholeid: '+ @wholeid+ ' prefix: '+ @prefix +' suffix: '+@suffix;
					SET @existsInAdnIds= (SELECT COUNT(*) FROM AdnIDs WHERE WholeID=@wholeid);	
					
					IF @existsInAdnIds =0  -- if the number does not exist enter it into adnids and adnrefs table 
					BEGIN
						IF @suffix='NULL'
						BEGIN
							INSERT INTO AdnIds  
							   ( ADNID ,  ADNtype , SeqID , WholeID , Status, RequestBy, AssignBy,  AssignDate,  PREFIX,  Suffix,  AdnTypeId) 
							VALUES(@nextAdnID, 'CDM:SCE Drawing', @seqid, @wholeid, 2 ,  1000, 1000, SYSDATETIME(), @prefix, NULL, 2);
						END;
						ELSE IF @suffix !='NULL'
						BEGIN 
							INSERT INTO AdnIds  
							   ( ADNID ,  ADNtype , SeqID , WholeID , Status, RequestBy, AssignBy,  AssignDate,  PREFIX,  Suffix,  AdnTypeId) 
							VALUES(@nextAdnID, 'CDM:SCE Drawing', @seqid, @wholeid, 2 ,  1000, 1000, SYSDATETIME(), @prefix, @suffix, 2);
						END;

						--PRINT 'insert into adnrefs';
						-- insert a line into the adnrefs table to keep track of the prefix for a dataid
						INSERT INTO AdnElements 
							   ( ADNID , ElementStyle, ElementIndex, ElementType, ElementValue, ElementKey) 
								VALUES ( @nextAdnID, 0           , 1           , 0          , @prefix     , 1         ); 
					END;
					SET @counter+=1;
					SET @nextAdnID +=1;
				END;

			-- after the while loop iterates throught the range record the numbers to generate
				IF @startSeq != ''
					BEGIN
						SET @trackedNums+= @startSeq+':'+CAST (@seqid AS NVARCHAR(20))+';';
					END;
				ELSE IF @startSeq = ''
					BEGIN
						SET @trackedNums+= @wholeid+';';
					END;
		END;
	--PRINT 'tracked numbers '+ @trackedNums;

	-- after creating the entries in the adnids table update the next available adnids table
	UPDATE c_CDMSUITE_ReservedADNIDs SET currentID=@nextAdnID;

	-- input 
	UPDATE C_CDMSUITE_DrawingRequest SET  ReservedNumbers=@trackedNums WHERE RequestID= @RequestID;
	
	-- return the requested numbers
	--format for range 5237294:5237298;251843:251843;5237299:5237301;717121:717123;485455:485458;
	--ShOrSect1 SEC 1 BK 1;ShOrSect2 SEC 2 BK 2;ShOrSect3 SEC 3 BK 3;
	--Tony Sub1 1/L;Tony Sub2 1/L;Tony Sub3 1/L;
	COMMIT;  
END;

ELSE
BEGIN 
--set @trackedNums= cast(@RequestID as nvarchar(255)) +'|'+(select ReservedNumbers from C_CDMSUITE_DrawingRequest where RequestID=@RequestID)
SET @trackedNums= (SELECT ReservedNumbers FROM C_CDMSUITE_DrawingRequest WHERE RequestID=@RequestID);
--PRINT @trackedNums;
END;

IF(@trackedNums IS NULL)
BEGIN
	--PRINT CAST(@RequestID AS NVARCHAR(255));
	SET @returnMessage = CAST(@RequestID AS NVARCHAR(255));
END;

ELSE
BEGIN
	--PRINT CAST(@RequestID AS NVARCHAR(255)) +'|'+@trackedNums;
	SET @returnMessage = CAST(@RequestID AS NVARCHAR(255))+'|'+@trackedNums;
END;

SELECT @returnMessage;
END;



GO
