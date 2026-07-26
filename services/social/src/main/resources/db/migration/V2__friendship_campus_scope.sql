-- V2__friendship_campus_scope.sql — friendships are scoped to the campus at request time

ALTER TABLE social.friendships
    ADD COLUMN campus_id UUID;

CREATE INDEX ix_friend_campus_status
    ON social.friendships (campus_id, status);