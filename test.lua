local Luck = require"luck"

local template = [[
  return {
      enum = OR(0, 1, 127, 128),
      region = LIST(NUM, OR(STRING, BOOL)), -- the first item must be NUM, rest must be STRING or BOOL
      kk = OR(
              { bar = TABLE(OR("momo", "ejoy"), RANGE(1,200)) },
              "hello",
              123,
              {foo1 = {foo2 = ANY}}
          ),
      start_time = OR(PATTERN("([%d]+)-([%d]+)-([%d]+)"), PATTERN("([%d]+)-([%d]+)-([%d]+) ([%d]+):([%d]+):([%d]+)")),

      mok = OR(4, NIL),
      title = STRING,
      count = RANGE(0),
      flag  = BOOL,
      num   = NUM,
}
]]

local cfgs = {
    {
        enum = 127,
        region = {0,"foo", true},

        kk = {bar = {momo = 199}},
        start_time = "1988-06-07",
        mok = 4,
        title = "correct one",
        count = 10000,
        flag = false,
        num = -1,
    },

    {
        enum = 300,             -- wrong enum
        region = {0,0,127, true, "foo"},
        start_time = "1988-06-07",
        kk = {bar = {momo = 199}},

        mok = 4,
        title = "correct one",
        count = 10000,
        flag = false,
        num = -1,
    },

    {
        enum = 0,
        region = {"foo", 127},
        start_time = "1988-06-07",
        kk = {bar = {tencent = 199}}, -- wrong key

        -- no mok
        title = "correct one",
        count = 0,
        flag = false,
        num = -1,
    },

    {
        enum = 128,
        region = {true,true},
        start_time = "1988-06-07",
        kk = {foo1 = {foo2 = "this can be anything"}},

        -- no mok
        title = "correct one",
        count = -2,             -- wrong range
        flag = false,
        num = -1,
    },
    
}


function main()
    local checker = Luck.new(Luck.load_chunk(template))

    for i,cfg in ipairs(cfgs) do
        local ok, err = checker:check(cfg)
        print(i, ok, err)
    end
end

main()
