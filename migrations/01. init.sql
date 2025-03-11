CREATE TABLE SimpleState (
    UserId INTEGER NOT NULL,
    Key TEXT NOT NULL,
    Value BLOB,
    PRIMARY KEY (UserId, Key)
);

CREATE TABLE Users (
    UserId INTEGER NOT NULL PRIMARY KEY,
    Username TEXT NOT NULL,
    Password TEXT NOT NULL
);
