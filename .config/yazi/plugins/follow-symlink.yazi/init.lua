return {
    entry = function()
        local h = cx.active.current.hovered
        local original_url = h.link_to
        ya.manager_emit(original_url and "reveal", { original_url })
    end,
}
