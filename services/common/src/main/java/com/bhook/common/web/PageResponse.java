package com.bhook.common.web;

import java.util.List;

public record PageResponse<T>(List<T> items, PageMeta page) {
    public record PageMeta(int limit, String nextCursor, boolean hasMore) {}
}
