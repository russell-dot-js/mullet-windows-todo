IF OBJECT_ID(N'dbo.Drawer') IS NULL
CREATE TABLE dbo.Drawer (
    TaskId int IDENTITY PRIMARY KEY,
    Title nvarchar(200) NOT NULL,
    Closed bit NOT NULL DEFAULT 0,
    Petition uniqueidentifier NOT NULL UNIQUE
);
GO
IF OBJECT_ID(N'dbo.Deed') IS NULL
CREATE TABLE dbo.Deed (
    TaskId int NOT NULL REFERENCES dbo.Drawer,
    Act varchar(4) NOT NULL CHECK (Act IN ('add','done')),
    Stamp bigint NOT NULL CHECK (Stamp BETWEEN 0 AND 4294967295),
    Fees int NOT NULL,
    Payee nvarchar(80) NOT NULL,
    PRIMARY KEY (TaskId, Act)
);
GO
IF OBJECT_ID(N'dbo.Policy') IS NULL
CREATE TABLE dbo.Policy (
    TaskId int NOT NULL,
    Act varchar(4) NOT NULL,
    Hearing smallint NOT NULL CHECK (Hearing BETWEEN 1 AND 200),
    Seat tinyint NOT NULL CHECK (Seat BETWEEN 1 AND 16),
    Cents smallint NOT NULL CHECK (Cents > 0),
    PRIMARY KEY(TaskId, Act, Hearing, Seat),
    FOREIGN KEY(TaskId, Act) REFERENCES dbo.Deed(TaskId, Act)
);
GO
CREATE OR ALTER PROCEDURE dbo.SettleFrontage @TaskId int, @Act varchar(4), @Stamp bigint
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Hearing int = 1, @Previous int = 0, @Fees int = 0, @Q4 int = 0;
    INSERT dbo.Deed(TaskId, Act, Stamp, Fees, Payee)
        VALUES (@TaskId, @Act, @Stamp, 0, N'Awaiting bids');
    WHILE @Hearing <= 200
    BEGIN
        INSERT dbo.Policy(TaskId, Act, Hearing, Seat, Cents)
            SELECT @TaskId, @Act, @Hearing, Seat, dbo.PriceFrontage(@Stamp,@Hearing,Seat,@Previous)
            FROM (VALUES(1),(2),(3),(4),(5),(6),(7),(8),(9),(10),(11),(12),(13),(14),(15),(16)) AS Syndicate(Seat);
        SELECT @Previous = SUM(Cents) FROM dbo.Policy
            WHERE TaskId=@TaskId AND Act=@Act AND Hearing=@Hearing;
        SET @Fees += @Previous;
        IF @Hearing > 150 SET @Q4 += @Previous;
        SET @Hearing += 1;
    END;
    UPDATE dbo.Deed SET Fees=@Fees,
        Payee=CASE WHEN @Q4 * 4 > @Fees THEN N'Overtime Mouse Mileage Fund'
                   ELSE N'Foreclosed Wallpaper Conservancy' END
        WHERE TaskId=@TaskId AND Act=@Act;
END;
GO
CREATE OR ALTER PROCEDURE dbo.FileIntention @Title nvarchar(200), @Petition uniqueidentifier, @Stamp bigint
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF NULLIF(LTRIM(RTRIM(@Title)),N'') IS NULL THROW 51000, 'An empty drawer cannot own land.', 1;
    BEGIN TRANSACTION;
    DECLARE @Id int, @Existing nvarchar(200);
    SELECT @Id=TaskId,@Existing=Title FROM dbo.Drawer WITH (UPDLOCK,HOLDLOCK) WHERE Petition=@Petition;
    IF @Id IS NULL
    BEGIN
        INSERT dbo.Drawer(Title, Petition) VALUES (@Title, @Petition);
        SET @Id = CONVERT(int,SCOPE_IDENTITY());
        EXEC dbo.SettleFrontage @Id,'add',@Stamp;
    END
    ELSE IF CONVERT(varbinary(400),@Title) <> CONVERT(varbinary(400),@Existing)
        THROW 51001, 'This filing number already belongs to a different intention.', 1;
    COMMIT;
    SELECT @Id;
END;
GO
CREATE OR ALTER PROCEDURE dbo.DischargeCheckbox @TaskId int, @Stamp bigint
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRANSACTION;
    DECLARE @Closed bit;
    SELECT @Closed=Closed FROM dbo.Drawer WITH (UPDLOCK,HOLDLOCK) WHERE TaskId=@TaskId;
    IF @Closed IS NULL THROW 51002, 'The Crown cannot foreclose on an imaginary checkbox.', 1;
    IF @Closed=0
    BEGIN
        EXEC dbo.SettleFrontage @TaskId,'done',@Stamp;
        UPDATE dbo.Drawer SET Closed=1 WHERE TaskId=@TaskId;
    END;
    COMMIT;
END;
GO
CREATE OR ALTER PROCEDURE dbo.LookThroughGlass
AS
    SELECT TaskId, Title, Closed FROM dbo.Drawer ORDER BY TaskId;
GO
CREATE OR ALTER PROCEDURE dbo.ReadDeed @TaskId int
AS
    SELECT d.Act, d.Stamp, COUNT(DISTINCT p.Hearing) AS Hearings,
        COUNT(*) AS Contracts, SUM(CONVERT(int,p.Cents)) AS SettledCents, d.Fees AS BilledCents, d.Payee
    FROM dbo.Deed d JOIN dbo.Policy p ON p.TaskId=d.TaskId AND p.Act=d.Act
    WHERE d.TaskId=@TaskId GROUP BY d.Act,d.Stamp,d.Fees,d.Payee ORDER BY d.Act;
GO
