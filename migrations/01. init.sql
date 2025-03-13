CREATE TABLE SimpleState (
    UserId INTEGER NOT NULL,
    Key TEXT NOT NULL,
    Value BLOB,
    PRIMARY KEY (UserId, Key)
);

CREATE TABLE Users (
    UserId INTEGER NOT NULL PRIMARY KEY,
    Username TEXT NOT NULL,
    Password BLOB NOT NULL,
    Salt TEXT NOT NULL
);

CREATE TABLE Sessions (
    UserId INTEGER NOT NULL,
    SessionId TEXT NOT NULL,
    ExpiresAt TEXT NOT NULL,
    PRIMARY KEY (UserId, SessionId)
);
