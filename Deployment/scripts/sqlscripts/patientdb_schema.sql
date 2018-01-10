/****** Object:  Table [dbo].[PatientData] ******/
SET ANSI_NULLS ON

SET QUOTED_IDENTIFIER ON

/*PatientData table*/
IF exists(SELECT * FROM sys.objects where object_id = OBJECT_ID(N'[dbo].[PatientData]') and TYPE in (N'U'))
begin
DROP TABLE [dbo].[PatientData]
end

CREATE TABLE [dbo].[PatientData](
	[FirstName] [nvarchar](50) NULL,
	[MiddleName] [nvarchar](50) NULL,
	[LastName] [nvarchar](50) NULL,
	[eid] [int] NOT NULL,
	[vdate] [date] NULL,
	[rcount] [nvarchar](5) NOT NULL,
	[gender] [nvarchar](1) NOT NULL,
	[dialysisrenalendstage] [int] NOT NULL,
	[asthma] [int] NOT NULL,
	[irondef] [int] NOT NULL,
	[pneum] [int] NOT NULL,
	[substancedependence] [int] NOT NULL,
	[psychologicaldisordermajor] [int] NOT NULL,
	[depress] [int] NOT NULL,
	[psychother] [int] NOT NULL,
	[fibrosisandother] [int] NOT NULL,
	[malnutrition] [int] NOT NULL,
	[hemo] [int] NOT NULL,
	[hematocrit] [float] NOT NULL,
	[neutrophils] [float] NOT NULL,
	[sodium] [float] NOT NULL,
	[glucose] [float] NOT NULL,
	[bloodureanitro] [float] NOT NULL,
	[creatinine] [float] NOT NULL,
	[bmi] [float] NOT NULL,
	[pulse] [int] NOT NULL,
	[respiration] [float] NOT NULL,
	[secondarydiagnosisnonicd9] [int] NOT NULL,
	[discharged] [date] NULL,
	[facid] [nvarchar](1) NOT NULL,
	[lengthofstay] [int] NULL,
	[predlengthofstay] [int] NULL,
	CONSTRAINT PK_PatientData_eid PRIMARY KEY CLUSTERED (eid)
)

GO

IF exists(SELECT * FROM sys.objects where object_id = OBJECT_ID(N'[dbo].[MetaData_Facilities]') and TYPE in (N'U'))
begin
DROP TABLE [dbo].[MetaData_Facilities]
end
CREATE TABLE [dbo].[MetaData_Facilities](
	[Capacity] [int] NOT NULL,
	[Id] [nvarchar](50) NOT NULL,
	[Name] [nvarchar](50) NOT NULL
)
GO

IF exists(SELECT * FROM sys.objects where object_id = OBJECT_ID(N'[dbo].[Train_Id]') and TYPE in (N'U'))
begin
DROP TABLE [dbo].[Train_Id]
end
CREATE TABLE [dbo].[Train_Id](
	[eid] [int] NOT NULL
)
GO

/*Patient type hold select query result on PatientData to avoid repeat select to PatientData table*/
IF TYPE_ID('[dbo].[Patient]') IS NOT NULL
begin
DROP TYPE [dbo].[Patient]
end
CREATE TYPE [dbo].[Patient] AS TABLE(
	[eid] [int] NULL,
	[vdate] [date] NULL,
	[lengthofstay] [int] NULL
)

GO

/*AdmitPatient Stored Procedure
* admit the patient if not already admitted
*/
IF EXISTS ( SELECT  *
            FROM    sys.objects
            WHERE   object_id = OBJECT_ID(N'[dbo].[AdmitPatient]')
                    AND type IN ( N'P', N'PC' ) )
begin
	DROP PROCEDURE [dbo].[AdmitPatient]
end

GO

CREATE PROCEDURE [dbo].[AdmitPatient]
@FirstName NVARCHAR (50), @MiddleName NVARCHAR (50),@eid int, @LastName NVARCHAR (50), @Vdate DATE, @Rcount NVARCHAR (5), @Gender NVARCHAR (1), @DialysisRenalEndStage INT, @Asthma INT, @IronDef INT, @Pneum INT, @SubstanceDependence INT, @PsychologicalDisorderMajor INT, @Depress INT, @Psychother INT, @FibrosisAndOther INT, @Malnutrition INT, @Hemo INT, @Hematocrit FLOAT, @Neutrophils FLOAT, @Sodium FLOAT, @Glucose FLOAT, @BloodUreaNitro FLOAT, @Creatinine FLOAT, @Bmi FLOAT, @Pulse INT, @Respiration FLOAT, @SecondaryDiagnosisNonIcd9 INT, @Facid NVARCHAR (1), @PredLengthOfStay INT, @result INT OUTPUT
AS
BEGIN TRY
    BEGIN TRANSACTION;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
    IF EXISTS (SELECT * FROM PatientData WHERE  eid = @eid)
    BEGIN
       SELECT @result=-1
    END
    ELSE
        BEGIN
            INSERT INTO PatientData (FirstName, MiddleName, LastName, eid, vdate, rcount, gender, dialysisrenalendstage, asthma, irondef, pneum, substancedependence, psychologicaldisordermajor, depress, psychother, fibrosisandother, malnutrition, hemo, hematocrit, neutrophils, sodium, glucose, bloodureanitro, creatinine, bmi, pulse, respiration, secondarydiagnosisnonicd9, facid, predlengthofstay)
            VALUES(@FirstName, @MiddleName, @LastName, @eid, @vdate, @rcount, @gender, @dialysisrenalendstage, @asthma, @irondef, @pneum, @substancedependence, @psychologicaldisordermajor, @depress, @psychother, @fibrosisandother, @malnutrition, @hemo, @hematocrit, @neutrophils, @sodium, @glucose, @bloodureanitro, @creatinine, @bmi, @pulse, @respiration, @secondarydiagnosisnonicd9, @facid, @predlengthofstay);
            SELECT @result=@eid
        END
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    ROLLBACK;
    SELECT @result = -200;
END CATCH

GO

/*DischargePatient Stored Procedure
* discharge the patient and update the lengthofstay with duration patient
* actually stayed in hospital.
*/
IF EXISTS ( SELECT  *
            FROM    sys.objects
            WHERE   object_id = OBJECT_ID(N'[dbo].[DischargePatient]')
                    AND type IN ( N'P', N'PC' ) )
begin
	DROP PROCEDURE [dbo].[DischargePatient]
end

GO

CREATE PROCEDURE [dbo].[DischargePatient]
@Eid INT,
@DischargeDate DATETIME,
@result INT OUTPUT
AS
BEGIN
    DECLARE @patientAdmissionDate AS DATETIME;
    DECLARE @patientDischargedDate AS DATETIME;
    DECLARE @patient AS Patient;
    DECLARE @lengthOfStay AS INT;
    BEGIN TRY
        BEGIN TRANSACTION;
        SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
        INSERT INTO @patient (eid, vdate, lengthofstay)
        SELECT eid,
               vdate,
               lengthofstay
        FROM   PatientData
        WHERE  eid = @Eid;
        IF EXISTS (SELECT *
                   FROM   @patient
                   WHERE  eid = @Eid)
            BEGIN
                SELECT @patientAdmissionDate = (SELECT vdate
                                                FROM   @patient);
                SELECT @patientDischargedDate = (SELECT @DischargeDate);
                SELECT @lengthOfStay = (SELECT DATEDIFF(DAY, @patientAdmissionDate, @patientDischargedDate));
                UPDATE PatientData
                SET    discharged   = @patientDischargedDate,
                       lengthofstay = @lengthOfStay
                WHERE  eid = @Eid;
                SELECT @result = @Eid;
            END
        ELSE
            BEGIN
                SET @result = -1;
            END
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK;
        SET @result = -200;
    END CATCH
END
GO

IF EXISTS ( SELECT  *
            FROM    sys.objects
            WHERE   object_id = OBJECT_ID(N'[dbo].[compute_stats]')
                    AND type IN ( N'P', N'PC' ) )
begin
	DROP PROCEDURE [dbo].[compute_stats]
end
GO

CREATE PROCEDURE [dbo].[compute_stats]  @input varchar(max) = 'LengthOfStay'
AS
BEGIN

	-- Create an empty table that will store the Statistics. 
	DROP TABLE if exists [dbo].[Stats]
	CREATE TABLE [dbo].[Stats](
		[variable_name] [varchar](30) NOT NULL,
		[type] [varchar](30) NOT NULL,
		[mode] [varchar](30) NULL, 
		[mean] [float] NULL,
		[std] [float] NULL
	)
	-- Get the names and variable types of the columns to analyze.
		DECLARE @sql nvarchar(max);
		SELECT @sql = N'
		INSERT INTO Stats(variable_name, type)
		SELECT *
		FROM (SELECT COLUMN_NAME as variable_name, DATA_TYPE as type
			  FROM INFORMATION_SCHEMA.COLUMNS
	          WHERE TABLE_NAME = ''' + @input + ''' 
			  AND COLUMN_NAME NOT IN (''eid'', ''lengthofstay'', ''vdate'', ''discharged'')) as t ';
		EXEC sp_executesql @sql;

	-- Loops to compute the Mode for categorical variables.
		DECLARE @name1 NVARCHAR(100)
		DECLARE @getname1 CURSOR

		SET @getname1 = CURSOR FOR
		SELECT variable_name FROM [dbo].[Stats] WHERE type IN('varchar', 'nvarchar', 'int')
	
		OPEN @getname1
		FETCH NEXT
		FROM @getname1 INTO @name1
		WHILE @@FETCH_STATUS = 0
		BEGIN	

			DECLARE @sql1 nvarchar(max);
			SELECT @sql1 = N'
			UPDATE Stats
			SET Stats.mode = T.mode
			FROM (SELECT TOP(1) ' + @name1 + ' as mode, count(*) as cnt
						 FROM ' + @input + ' 
						 GROUP BY ' + @name1 + ' 
						 ORDER BY cnt desc) as T
			WHERE Stats.variable_name =  ''' + @name1 + '''';
			EXEC sp_executesql @sql1;

			FETCH NEXT
		    FROM @getname1 INTO @name1
		END
		CLOSE @getname1
		DEALLOCATE @getname1
		
	-- Loops to compute the Mean and Standard Deviation for continuous variables.
		DECLARE @name2 NVARCHAR(100)
		DECLARE @getname2 CURSOR

		SET @getname2 = CURSOR FOR
		SELECT variable_name FROM [dbo].[Stats] WHERE type IN('float')
	
		OPEN @getname2
		FETCH NEXT
		FROM @getname2 INTO @name2
		WHILE @@FETCH_STATUS = 0
		BEGIN	

			DECLARE @sql2 nvarchar(max);
			SELECT @sql2 = N'
			UPDATE Stats
			SET Stats.mean = T.mean,
				Stats.std = T.std
			FROM (SELECT  AVG(' + @name2 + ') as mean, STDEV(' + @name2 + ') as std
				  FROM ' + @input + ') as T
			WHERE Stats.variable_name =  ''' + @name2 + '''';
			EXEC sp_executesql @sql2;

			FETCH NEXT
		    FROM @getname2 INTO @name2
		END
		CLOSE @getname2
		DEALLOCATE @getname2

END
GO

IF EXISTS ( SELECT  *
            FROM    sys.objects
            WHERE   object_id = OBJECT_ID(N'[dbo].[evaluate]')
                    AND type IN ( N'P', N'PC' ) )
begin
	DROP PROCEDURE [dbo].[evaluate]
end
GO

CREATE PROCEDURE [dbo].[evaluate] @model_name varchar(20),
							@predictions_table varchar(max)


AS 
BEGIN
	-- Create an empty table to be filled with the Metrics.
	IF NOT EXISTS (SELECT * FROM sysobjects WHERE name = 'Metrics' AND xtype = 'U')
	CREATE TABLE [dbo].[Metrics](
		[model_name] [varchar](30) NOT NULL,
		[mean_absolute_error] [float] NULL,
		[root_mean_squared_error] [float] NULL,
		[relative_absolute_error] [float] NULL,
		[relative_squared_error] [float] NULL,
		[coefficient_of_determination] [float] NULL
		)

	-- Import the Predictions Table as an input to the R code, and get the current database name. 
	DECLARE @inquery nvarchar(max) = N' SELECT * FROM ' + @predictions_table  
	DECLARE @database_name varchar(max) = db_name();
	INSERT INTO Metrics 
	EXECUTE sp_execute_external_script @language = N'R',
     					   @script = N' 

##########################################################################################################################################
##	Define the connection string
##########################################################################################################################################
connection_string <- paste("Driver=SQL Server;Server=localhost;Database=", database_name, ";Trusted_Connection=true;", sep="")

##########################################################################################################################################
## Model evaluation metrics.
##########################################################################################################################################
evaluate_model <- function(observed, predicted, model) {
  mean_observed <- mean(observed)
  se <- (observed - predicted)^2
  ae <- abs(observed - predicted)
  sem <- (observed - mean_observed)^2
  aem <- abs(observed - mean_observed)
  mae <- mean(ae)
  rmse <- sqrt(mean(se))
  rae <- sum(ae) / sum(aem)
  rse <- sum(se) / sum(sem)
  rsq <- 1 - rse
  metrics <- c(model, mae, rmse, rae, rse, rsq)
  print(model)
  print("Summary statistics of the absolute error")
  print(summary(abs(observed-predicted)))
  return(metrics)
 }

##########################################################################################################################################
## Random forest Evaluation 
##########################################################################################################################################
if(model_name == "RF"){
	OutputDataSet <- data.frame(rbind(evaluate_model(observed = InputDataSet$lengthofstay,
							        predicted = InputDataSet$lengthofstay_Pred,
							        model = "Random Forest (rxDForest)")))
 }
##########################################################################################################################################
## Boosted tree Evaluation.
##########################################################################################################################################
if(model_name == "GBT"){
	library("MicrosoftML")
	OutputDataSet <- data.frame(rbind(evaluate_model(observed = InputDataSet$lengthofstay,
							        predicted = InputDataSet$Score,
							        model = "Boosted Trees (rxFastTrees)")))
}'
, @input_data_1 = @inquery
, @params = N' @model_name varchar(20), @predictions_table varchar(max), @database_name varchar(max)'	  
, @model_name = @model_name 
, @predictions_table = @predictions_table 
, @database_name = @database_name
;
END
GO

IF EXISTS ( SELECT  *
            FROM    sys.objects
            WHERE   object_id = OBJECT_ID(N'[dbo].[feature_engineering]')
                    AND type IN ( N'P', N'PC' ) )
begin
	DROP PROCEDURE [dbo].[feature_engineering]
end
GO

CREATE PROCEDURE [dbo].[feature_engineering]  @input varchar(max), @output varchar(max), @is_production int
AS
BEGIN 

-- Drop the output table if it has been created in R in the same database. 
    DECLARE @sql0 nvarchar(max);
	SELECT @sql0 = N'
	IF OBJECT_ID (''' + @output + ''', ''U'') IS NOT NULL  
	DROP TABLE ' + @output ;  
	EXEC sp_executesql @sql0

-- Drop the output view if it already exists. 
	DECLARE @sql1 nvarchar(max);
	SELECT @sql1 = N'
	IF OBJECT_ID (''' + @output + ''', ''V'') IS NOT NULL  
	DROP VIEW ' + @output ;  
	EXEC sp_executesql @sql1

-- Create a View with new features:
-- 1- Standardize the health numeric variables by substracting the mean and dividing by the standard deviation. 
-- 2- Create number_of_issues variable corresponding to the total number of preidentified medical conditions. 
-- lengthofstay variable is only selected if it exists (ie. in Modeling pipeline).

	DECLARE @sql2 nvarchar(max);
	SELECT @sql2 = N'
		CREATE VIEW ' + @output + '
		AS
		SELECT eid, vdate, rcount, gender, dialysisrenalendstage, asthma, irondef, pneum, substancedependence, psychologicaldisordermajor, depress,
			   psychother, fibrosisandother, malnutrition, hemo,
		       (hematocrit - (SELECT mean FROM [dbo].[Stats] WHERE variable_name = ''hematocrit''))/(SELECT std FROM [dbo].[Stats] WHERE variable_name = ''hematocrit'') AS hematocrit,
		       (neutrophils - (SELECT mean FROM [dbo].[Stats] WHERE variable_name = ''neutrophils''))/(SELECT std FROM [dbo].[Stats] WHERE variable_name = ''neutrophils'') AS neutrophils,
		       (sodium - (SELECT mean FROM [dbo].[Stats] WHERE variable_name = ''sodium ''))/(SELECT std FROM [dbo].[Stats] WHERE variable_name = ''sodium '') AS sodium,
		       (glucose - (SELECT mean FROM [dbo].[Stats] WHERE variable_name = ''glucose''))/(SELECT std FROM [dbo].[Stats] WHERE variable_name = ''glucose'') AS glucose,
		       (bloodureanitro - (SELECT mean FROM [dbo].[Stats] WHERE variable_name = ''bloodureanitro''))/(SELECT std FROM [dbo].[Stats] WHERE variable_name = ''bloodureanitro'') AS bloodureanitro,
		       (creatinine - (SELECT mean FROM [dbo].[Stats] WHERE variable_name = ''creatinine''))/(SELECT std FROM [dbo].[Stats] WHERE variable_name = ''creatinine'') AS creatinine,
		       (bmi - (SELECT mean FROM [dbo].[Stats] WHERE variable_name = ''bmi''))/(SELECT std FROM [dbo].[Stats] WHERE variable_name = ''bmi'') AS bmi,
		       (pulse - (SELECT mean FROM [dbo].[Stats] WHERE variable_name = ''pulse''))/(SELECT std FROM [dbo].[Stats] WHERE variable_name = ''pulse'') AS pulse,
		       (respiration - (SELECT mean FROM [dbo].[Stats] WHERE variable_name = ''respiration''))/(SELECT std FROM [dbo].[Stats] WHERE variable_name = ''respiration'') AS respiration,
		       CAST((CAST(hemo as int) + CAST(dialysisrenalendstage as int) + CAST(asthma as int) + CAST(irondef as int) + CAST(pneum as int) +
			        CAST(substancedependence as int) + CAST(psychologicaldisordermajor as int) + CAST(depress as int) +
                    CAST(psychother as int) + CAST(fibrosisandother as int) + CAST(malnutrition as int)) as varchar(2)) 
               AS number_of_issues,
			   secondarydiagnosisnonicd9, discharged, facid, '+
			   (CASE WHEN @is_production = 0 THEN 'lengthofstay' else 'NULL as lengthofstay' end) + '
	    FROM ' + @input;
	EXEC sp_executesql @sql2

;
END
GO

IF EXISTS ( SELECT  *
            FROM    sys.objects
            WHERE   object_id = OBJECT_ID(N'[dbo].[fill_NA_explicit]')
                    AND type IN ( N'P', N'PC' ) )
begin
	DROP PROCEDURE [dbo].[fill_NA_explicit]
end
GO

CREATE PROCEDURE [dbo].[fill_NA_explicit]  @input varchar(max), @output varchar(max)
AS
BEGIN

    -- Drop the output table if it has been created in R in the same database. 
    DECLARE @sql0 nvarchar(max);
	SELECT @sql0 = N'
	IF OBJECT_ID (''' + @output + ''', ''U'') IS NOT NULL  
	DROP TABLE ' + @output ;  
	EXEC sp_executesql @sql0

	-- Create a View with the raw data. 
	DECLARE @sqlv1 nvarchar(max);
	SELECT @sqlv1 = N'
	IF OBJECT_ID (''' + @output + ''', ''V'') IS NOT NULL  
	DROP VIEW ' + @output ;  
	EXEC sp_executesql @sqlv1

	DECLARE @sqlv2 nvarchar(max);
	SELECT @sqlv2 = N'
		CREATE VIEW ' + @output + '
		AS
		SELECT *
	    FROM ' + @input;
	EXEC sp_executesql @sqlv2

    -- Loops to fill missing values for the character variables with 'missing'. 
	DECLARE @name1 NVARCHAR(100)
	DECLARE @getname1 CURSOR

	SET @getname1 = CURSOR FOR
	SELECT variable_name FROM [dbo].[Stats] WHERE type IN ('varchar', 'nvarchar')

	OPEN @getname1
	FETCH NEXT
	FROM @getname1 INTO @name1
	WHILE @@FETCH_STATUS = 0
	BEGIN	

		-- Check whether the variable contains a missing value. We perform cleaning only for variables containing NULL. 
		DECLARE @missing1 varchar(50)
		DECLARE @sql10 nvarchar(max);
		DECLARE @Parameter10 nvarchar(500);
		SELECT @sql10 = N'
			SELECT @missingOUT1 = missing
			FROM (SELECT count(*) - count(' + @name1 + ') as missing
			      FROM ' + @output + ') as t';
		SET @Parameter10 = N'@missingOUT1 varchar(max) OUTPUT';
		EXEC sp_executesql @sql10, @Parameter10, @missingOUT1=@missing1 OUTPUT;

		IF (@missing1 > 0)
		BEGIN 

			-- Replace character variables with 'missing'. 
				DECLARE @sql11 nvarchar(max)
				SET @sql11 = 
				'UPDATE ' + @output + '
				SET ' + @name1 + ' = ISNULL(' + @name1 + ',''missing'')';
				EXEC sp_executesql @sql11;
		END;
		FETCH NEXT
		FROM @getname1 INTO @name1
	END
	CLOSE @getname1
	DEALLOCATE @getname1

    -- Loops to fill numeric variables with '-1'.  
	DECLARE @name2 NVARCHAR(100)
	DECLARE @getname2 CURSOR

	SET @getname2 = CURSOR FOR
	SELECT variable_name FROM [dbo].[Stats] WHERE type IN ('int', 'float')

	OPEN @getname2
	FETCH NEXT
	FROM @getname2 INTO @name2
	WHILE @@FETCH_STATUS = 0
	BEGIN	

		-- Check whether the variable contains a missing value. We perform cleaning only for variables containing NULL. 
		DECLARE @missing2 varchar(50)
		DECLARE @sql20 nvarchar(max);
		DECLARE @Parameter20 nvarchar(500);
		SELECT @sql20 = N'
			SELECT @missingOUT2 = missing
			FROM (SELECT count(*) - count(' + @name2 + ') as missing
			      FROM ' + @output + ') as t';
		SET @Parameter20 = N'@missingOUT2 varchar(max) OUTPUT';
		EXEC sp_executesql @sql20, @Parameter20, @missingOUT2=@missing2 OUTPUT;

		IF (@missing2 > 0)
		BEGIN 

			-- Replace numeric variables with '-1'. 
				DECLARE @sql21 nvarchar(max)
				SET @sql21 = 
				'UPDATE ' + @output + '
				 SET ' + @name2 + ' = ISNULL(' + @name2 + ', -1)';
				EXEC sp_executesql @sql21;
		END;
		FETCH NEXT
		FROM @getname2 INTO @name2
	END
	CLOSE @getname2
	DEALLOCATE @getname2
END
GO

IF EXISTS ( SELECT  *
            FROM    sys.objects
            WHERE   object_id = OBJECT_ID(N'[dbo].[fill_NA_mode_mean]')
                    AND type IN ( N'P', N'PC' ) )
begin
	DROP PROCEDURE [dbo].[fill_NA_mode_mean]
end
GO

CREATE PROCEDURE [dbo].[fill_NA_mode_mean]  @input varchar(max), @output varchar(max)
AS
BEGIN

    -- Drop the output table if it has been created in R in the same database. 
    DECLARE @sql0 nvarchar(max);
	SELECT @sql0 = N'
	IF OBJECT_ID (''' + @output + ''', ''U'') IS NOT NULL  
	DROP TABLE ' + @output ;  
	EXEC sp_executesql @sql0

	-- Create a View with the raw data. 
	DECLARE @sqlv1 nvarchar(max);
	SELECT @sqlv1 = N'
	IF OBJECT_ID (''' + @output + ''', ''V'') IS NOT NULL  
	DROP VIEW ' + @output ;  
	EXEC sp_executesql @sqlv1

	DECLARE @sqlv2 nvarchar(max);
	SELECT @sqlv2 = N'
		CREATE VIEW ' + @output + '
		AS
		SELECT *
	    FROM ' + @input;
	EXEC sp_executesql @sqlv2

    -- Loops to fill missing values for the categorical variables with the mode. 
	DECLARE @name1 NVARCHAR(100)
	DECLARE @getname1 CURSOR

	SET @getname1 = CURSOR FOR
	SELECT variable_name FROM  [dbo].[Stats] WHERE type IN ('varchar', 'nvarchar', 'int')

	OPEN @getname1
	FETCH NEXT
	FROM @getname1 INTO @name1
	WHILE @@FETCH_STATUS = 0
	BEGIN	

		-- Check whether the variable contains a missing value. We perform cleaning only for variables containing NULL. 
		DECLARE @missing1 varchar(50)
		DECLARE @sql10 nvarchar(max);
		DECLARE @Parameter10 nvarchar(500);
		SELECT @sql10 = N'
			SELECT @missingOUT1 = missing
			FROM (SELECT count(*) - count(' + @name1 + ') as missing
			      FROM ' + @output + ') as t';
		SET @Parameter10 = N'@missingOUT1 varchar(max) OUTPUT';
		EXEC sp_executesql @sql10, @Parameter10, @missingOUT1=@missing1 OUTPUT;

		IF (@missing1 > 0)
		BEGIN 
			-- Replace categorical variables with the mode. 
			DECLARE @sql11 nvarchar(max)
			SET @sql11 = 
			'UPDATE ' + @output + '
			SET ' + @name1 + ' = ISNULL(' + @name1 + ', (SELECT mode FROM [dbo].[Stats] WHERE variable_name = ''' + @name1 + '''))';
			EXEC sp_executesql @sql11;
		END;
		FETCH NEXT
		FROM @getname1 INTO @name1
	END
	CLOSE @getname1
	DEALLOCATE @getname1

    -- Loops to fill continous variables with the mean.  
	DECLARE @name2 NVARCHAR(100)
	DECLARE @getname2 CURSOR

	SET @getname2 = CURSOR FOR
	SELECT variable_name FROM  [dbo].[Stats] WHERE type IN ('float')

	OPEN @getname2
	FETCH NEXT
	FROM @getname2 INTO @name2
	WHILE @@FETCH_STATUS = 0
	BEGIN	

		-- Check whether the variable contains a missing value. We perform cleaning only for variables containing NULL. 
		DECLARE @missing2 varchar(50)
		DECLARE @sql20 nvarchar(max);
		DECLARE @Parameter20 nvarchar(500);
		SELECT @sql20 = N'
			SELECT @missingOUT2 = missing
			FROM (SELECT count(*) - count(' + @name2 + ') as missing
			      FROM ' + @output + ') as t';
		SET @Parameter20 = N'@missingOUT2 varchar(max) OUTPUT';
		EXEC sp_executesql @sql20, @Parameter20, @missingOUT2=@missing2 OUTPUT;

		IF (@missing2 > 0)
		BEGIN 
			-- Replace numeric variables with '-1'. 
			DECLARE @sql21 nvarchar(max)
			SET @sql21 = 
			'UPDATE ' + @output + '
			SET ' + @name2 + ' = ISNULL(' + @name2 + ', (SELECT mean FROM [dbo].[Stats] WHERE variable_name = ''' + @name2 + '''))';
			EXEC sp_executesql @sql21;
		END;
		FETCH NEXT
		FROM @getname2 INTO @name2
	END
	CLOSE @getname2
	DEALLOCATE @getname2
END
GO

IF EXISTS ( SELECT  *
            FROM    sys.objects
            WHERE   object_id = OBJECT_ID(N'[dbo].[get_column_info]')
                    AND type IN ( N'P', N'PC' ) )
begin
	DROP PROCEDURE [dbo].[get_column_info]
end
GO

CREATE PROCEDURE [dbo].[get_column_info] @input varchar(max)
AS 
BEGIN
	-- Create an empty table to store the serialized column information. 
	DROP TABLE IF EXISTS [dbo].[ColInfo]
	CREATE TABLE [dbo].[ColInfo](
		[info] [varbinary](max) NOT NULL
		)

	-- Serialize the column information. 
	DECLARE @database_name varchar(max) = db_name()
	INSERT INTO ColInfo
	EXECUTE sp_execute_external_script @language = N'R',
     					               @script = N' 

connection_string <- paste("Driver=SQL Server;Server=localhost;Database=", database_name, ";Trusted_Connection=true;", sep="");
LoS <- RxSqlServerData(sqlQuery = sprintf( "SELECT *  FROM [%s]", input),
					   connectionString = connection_string, 
					   stringsAsFactors = T)
OutputDataSet <- data.frame(payload = as.raw(serialize(rxCreateColInfo(LoS), connection=NULL)))
'
, @params = N'@input varchar(max), @database_name varchar(max)'
, @input = @input
, @database_name = @database_name 
;
END
GO

IF EXISTS ( SELECT  *
            FROM    sys.objects
            WHERE   object_id = OBJECT_ID(N'[dbo].[prediction_results]')
                    AND type IN ( N'P', N'PC' ) )
begin
	DROP PROCEDURE [dbo].[prediction_results]
end
GO

CREATE PROCEDURE [dbo].[prediction_results] 
AS 
BEGIN

	DROP TABLE if exists LoS_Predictions
  
	SELECT LoS0.eid, CONVERT(DATE, LoS0.vdate, 110) as vdate, LoS0.rcount, LoS0.gender, LoS0.dialysisrenalendstage, 
		   LoS0.asthma, LoS0.irondef, LoS0.pneum, LoS0.substancedependence,
		   LoS0.psychologicaldisordermajor, LoS0.depress, LoS0.psychother, LoS0.fibrosisandother, 
		   LoS0.malnutrition, LoS0.hemo, LoS0.hematocrit, LoS0.neutrophils, LoS0.sodium, 
	       LoS0.glucose, LoS0.bloodureanitro, LoS0.creatinine, LoS0.bmi, LoS0.pulse, LoS0.respiration, number_of_issues, LoS0.secondarydiagnosisnonicd9, 
           CONVERT(DATE, LoS0.discharged, 110) as discharged, LoS0.facid, LoS.lengthofstay, 
	       CONVERT(DATE, CONVERT(DATETIME, LoS0.vdate, 110) + CAST(ROUND(Score, 0) as int), 110) as discharged_pred_boosted,
		   CAST(ROUND(Score, 0) as int) as Score
     INTO LoS_Predictions
     FROM LoS JOIN Boosted_Prediction ON LoS.eid = Boosted_Prediction.eid JOIN LoS0 ON LoS.eid = LoS0.eid
;
END
GO

IF EXISTS ( SELECT  *
            FROM    sys.objects
            WHERE   object_id = OBJECT_ID(N'[dbo].[score]')
                    AND type IN ( N'P', N'PC' ) )
begin
	DROP PROCEDURE [dbo].[score]
end
GO

CREATE PROCEDURE [dbo].[score] @model_name varchar(20), 
						 @inquery varchar(max),
						 @output varchar(max)

AS 
BEGIN

	--	Get the trained model, the current database name and the column information.
	DECLARE @model varbinary(max) = (select model from [dbo].[Models] where model_name = @model_name);
	DECLARE @database_name varchar(max) = db_name();
	DECLARE @info varbinary(max) = (select * from [dbo].[ColInfo]);
	-- Compute the predictions. 
	EXECUTE sp_execute_external_script @language = N'R',
     					               @script = N' 

##########################################################################################################################################
##	Define the connection string
##########################################################################################################################################
connection_string <- paste("Driver=SQL Server;Server=localhost;Database=", database_name, ";Trusted_Connection=true;", sep="")

##########################################################################################################################################
##	Get the column information.
##########################################################################################################################################
column_info <- unserialize(info)

##########################################################################################################################################
## Point to the data set to score and use the column_info list to specify the types of the features.
##########################################################################################################################################
 LoS_Test <- RxSqlServerData(sqlQuery = sprintf("%s", inquery),
							 connectionString = connection_string,
							 colInfo = column_info)

##########################################################################################################################################
## Random forest scoring.
##########################################################################################################################################
# The prediction results are directly written to a SQL table. 
if(model_name == "RF" & length(model) > 0){
	model <- unserialize(model)

	forest_prediction_sql <- RxSqlServerData(table = output, connectionString = connection_string, stringsAsFactors = T)

	rxPredict(modelObject = model,
			 data = LoS_Test,
			 outData = forest_prediction_sql,
			 type = "response",
			 extraVarsToWrite = c("eid", "lengthofstay"),
			 overwrite = TRUE)
 }
##########################################################################################################################################
## Boosted tree scoring.
##########################################################################################################################################
# The prediction results are directly written to a SQL table.
if(model_name == "GBT" & length(model) > 0){
	library("MicrosoftML")
	model <- unserialize(model)

	boosted_prediction_sql <- RxSqlServerData(table = output, connectionString = connection_string, stringsAsFactors = T)

	rxPredict(modelObject = model,
			data = LoS_Test,
			outData = boosted_prediction_sql,
			extraVarsToWrite = c("eid", "lengthofstay"),
			overwrite = TRUE)
 }	 		   	   	   
'
, @params = N' @model_name varchar(20), @model varbinary(max), @inquery nvarchar(max), @database_name varchar(max), @info varbinary(max), @output varchar(max)'	  
, @model_name = @model_name
, @model = @model
, @inquery = @inquery
, @database_name = @database_name
, @info = @info
, @output = @output 
;
END
GO

IF EXISTS ( SELECT  *
            FROM    sys.objects
            WHERE   object_id = OBJECT_ID(N'[dbo].[splitting]')
                    AND type IN ( N'P', N'PC' ) )
begin
	DROP PROCEDURE [dbo].[splitting]
end
GO

CREATE PROCEDURE [dbo].[splitting]  @splitting_percent int = 70, @input varchar(max) 
AS
BEGIN

  DECLARE @sql nvarchar(max);
  SET @sql = N'
  DROP TABLE IF EXISTS Train_Id
  SELECT eid 
  INTO Train_Id
  FROM ' + @input + ' 
  WHERE ABS(CAST(BINARY_CHECKSUM(eid, NEWID()) as int)) % 100 < ' + Convert(Varchar, @splitting_percent);

  EXEC sp_executesql @sql
;
END
GO

IF EXISTS ( SELECT  *
            FROM    sys.objects
            WHERE   object_id = OBJECT_ID(N'[dbo].[train_model]')
                    AND type IN ( N'P', N'PC' ) )
begin
	DROP PROCEDURE [dbo].[train_model]
end
GO

CREATE PROCEDURE [dbo].[train_model]   @modelName varchar(20),
								 @dataset_name varchar(max) 
AS 
BEGIN

	-- Create an empty table to be filled with the trained models.
	IF NOT EXISTS (SELECT * FROM sysobjects WHERE name = 'Models' AND xtype = 'U')
	CREATE TABLE [dbo].[Models](
		[model_name] [varchar](30) NOT NULL default('default model'),
		[model] [varbinary](max) NOT NULL
		)

	-- Get the database name and the column information. 
	DECLARE @info varbinary(max) = (select * from [dbo].[ColInfo]);
	DECLARE @database_name varchar(max) = db_name();

	-- Train the model on the training set.	
	DELETE FROM Models WHERE model_name = @modelName;
	INSERT INTO Models (model)
	EXECUTE sp_execute_external_script @language = N'R',
									   @script = N' 

##########################################################################################################################################
##	Set the compute context to SQL for faster training
##########################################################################################################################################
# Define the connection string
connection_string <- paste("Driver=SQL Server;Server=localhost;Database=", database_name, ";Trusted_Connection=true;", sep="")

# Set the Compute Context to SQL.
sql <- RxInSqlServer(connectionString = connection_string)
rxSetComputeContext(sql)

##########################################################################################################################################
##	Get the column information.
##########################################################################################################################################
column_info <- unserialize(info)

##########################################################################################################################################
##	Point to the training set and use the column_info list to specify the types of the features.
##########################################################################################################################################
LoS_Train <- RxSqlServerData(  
  sqlQuery = sprintf( "SELECT *   
                       FROM [%s]
                       WHERE eid IN (SELECT eid from Train_Id)", dataset_name),
  connectionString = connection_string, 
  colInfo = column_info)

##########################################################################################################################################
##	Specify the variables to keep for the training 
##########################################################################################################################################
variables_all <- rxGetVarNames(LoS_Train)
# We remove dates and ID variables.
variables_to_remove <- c("eid", "vdate", "discharged", "facid")
traning_variables <- variables_all[!(variables_all %in% c("lengthofstay", variables_to_remove))]
formula <- as.formula(paste("lengthofstay ~", paste(traning_variables, collapse = "+")))

##########################################################################################################################################
## Training model based on model selection
##########################################################################################################################################
# Parameters of both models have been chosen for illustrative purposes, and can be further optimized.

if (model_name == "RF") {
	# Train the Random Forest.
	model <- rxDForest(formula = formula,
	 	           data = LoS_Train,
			       nTree = 40,
 		           minBucket = 5,
		           minSplit = 10,
		           cp = 0.00005,
		           seed = 5)
} else{
	# Train the Gradient Boosted Trees (rxFastTrees implementation).
	library("MicrosoftML")
	model <- rxFastTrees(formula = formula,
			     data = LoS_Train,
			     type=c("regression"),
			     numTrees = 40,
			     learningRate = 0.2,
			     splitFraction = 5/24,
			     featureFraction = 1,
                             minSplit = 10)	
}				   				       
OutputDataSet <- data.frame(payload = as.raw(serialize(model, connection=NULL)))'
, @params = N' @model_name varchar(20), @dataset_name varchar(max), @info varbinary(max), @database_name varchar(max)'
, @model_name = @modelName 
, @dataset_name =  @dataset_name
, @info = @info
, @database_name = @database_name

UPDATE Models set model_name = @modelName 
WHERE model_name = 'default model'

;
END
GO
