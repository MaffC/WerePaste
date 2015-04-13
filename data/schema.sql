CREATE TABLE posts  (
    id TEXT PRIMARY KEY NOT NULL,
    ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL, /* Created timestamp */
    expiration TIMESTAMP,                            /* Created timestamp */
    language TEXT NOT NULL,                          /* Language (if detected) */
    title TEXT,                                      /* Title/Filename */
    code BLOB NOT NULL,                              /* Code */
    html BLOB                                        /* HTML version of Code */
);
