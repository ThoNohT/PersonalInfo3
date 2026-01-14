CREATE TABLE SimpleState (
    UserId INTEGER NOT NULL,
    Key TEXT NOT NULL,
    Value BLOB,

    CONSTRAINT PK_SimpleState PRIMARY KEY (UserId, Key)
);

CREATE TABLE Users (
    UserId INTEGER NOT NULL,
    Username TEXT NOT NULL,
    Password BLOB NOT NULL,
    Salt TEXT NOT NULL,

    CONSTRAINT PK_Users PRIMARY KEY (UserId)
);

CREATE TABLE Sessions (
    UserId INTEGER NOT NULL,
    SessionId TEXT NOT NULL,
    ExpiresAt TEXT NOT NULL,

    CONSTRAINT PK_Sessions PRIMARY KEY (UserId, SessionId),
    CONSTRAINT UQ_Sessions UNIQUE (SessionId)
);
