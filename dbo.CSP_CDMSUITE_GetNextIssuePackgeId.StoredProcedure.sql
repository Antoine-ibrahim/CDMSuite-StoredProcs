
/****** Object:  StoredProcedure [dbo].[CSP_CDMSUITE_GetNextIssuePackgeId]    Script Date: 10/16/2017 1:36:28 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Antoine Ibrahim
-- Description:	Will return the next valid package ID.
-- =============================================
CREATE PROCEDURE [dbo].[CSP_CDMSUITE_GetNextIssuePackgeId]
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;	
	DECLARE	@PackageId NVARCHAR(50); 
	DECLARE @LastValue INT;	
	
	-- Get current year and month
	DECLARE @CurrentYear INT;
	DECLARE @CurrentMonth INT;

	SELECT @CurrentYear = (YEAR(GETDATE()) % 100);
	SELECT @CurrentMonth = MONTH(GETDATE());

	--PRINT 'Year ' + CAST(@CurrentYear AS NVARCHAR(10));
	--PRINT 'Month ' + CAST(@CurrentMonth AS NVARCHAR(10));
	
	-- Check to see if there is an entry with the current year and month
	SELECT @LastValue = LastValue FROM C_CDMSUITE_IssuePackageLookup WHERE IssueYear = @CurrentYear AND IssueMonth = @CurrentMonth;
	
	
	IF(@LastValue IS NULL)
	BEGIN
		--PRINT 'New Year and Month, will need to add new entry';
		SELECT @LastValue = 1;
		INSERT INTO C_CDMSUITE_IssuePackageLookup (IssueYear, IssueMonth, LastValue, DateModified)
			VALUES (@CurrentYear, @CurrentMonth, @LastValue, SYSDATETIME());
	END;
	ELSE
	BEGIN
		--PRINT 'Found value, will need to update LastValue';
		--PRINT 'Last Value before ' + CAST(@LastValue AS NVARCHAR(5));
		SELECT @LastValue = @LastValue + 1;
		PRINT 'Last Value after ' + CAST(@LastValue AS NVARCHAR(5));
		UPDATE C_CDMSUITE_IssuePackageLookup SET LastValue = @LastValue, DateModified = SYSDATETIME() WHERE IssueYear = @CurrentYear AND IssueMonth = @CurrentMonth;
	END;

	-- Return string with new Package ID
	--PRINT 'Printing year, month last value';
	--PRINT FORMAT(@CurrentYear, '00');
	--PRINT FORMAT(@CurrentMonth, '00');
	--PRINT FORMAT(@LastValue, '000');

	SELECT FORMAT(@CurrentYear, '00') + 'D' + FORMAT(@CurrentMonth, '00') + FORMAT(@LastValue, '000');
	

END;



GO
