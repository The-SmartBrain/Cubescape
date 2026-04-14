pub const Block = struct {
    id: BlockID,
    pub const BlockID = enum {
        empty,
        simple,
    };
};
