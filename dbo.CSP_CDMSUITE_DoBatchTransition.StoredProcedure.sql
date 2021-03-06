
/****** Object:  StoredProcedure [dbo].[CSP_CDMSUITE_DoBatchTransition]    Script Date: 10/16/2017 1:36:28 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Antoine Ibrahim
-- Description:	This stored procedure will be used to mimic the bactch transition process and change the 
-- transition state of a particular node 
-- =============================================
CREATE PROCEDURE [dbo].[CSP_CDMSUITE_DoBatchTransition]
	@StateID BIGINT,			-- The new state id 
	@PriorStateID BIGINT,		-- The previous state id
	@NodeId NVARCHAR(255)		-- The node id 
AS
BEGIN
	
	-- See if this node id already has an entry in the lifeccyles table.
	DECLARE @alreadyExists INT
	SELECT @alreadyExists = COUNT(1) FROM LM_Lifecycles WHERE DataID = @NodeId

	IF (@alreadyExists > 0)
	BEGIN
		UPDATE Lm_lifecycles SET 
			StateID = @StateID, 
			PriorStateID = @PriorStateID 
		WHERE DataID = @NodeId	
	END
	ELSE
	BEGIN
		INSERT INTO LM_Lifecycles 
				( DataID,  StateID, InTransition, NextState,  PriorStateID)
		VALUES	(@NodeId, @StateID, 0           , -1       , @PriorStateID)
	END
END

GO
