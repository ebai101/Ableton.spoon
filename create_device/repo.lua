local repo = {}

local log = hs.logger.new('repo', 'debug')

repo.path = 'abcd_freq_data.db'
repo.connected = false

function repo:open()
    if self.connected then
        log.d('repo already connected')
        return
    end

    self.db = hs.sqlite3.open(self.path)

    -- schema
    local res = self.db:exec [=[
        create table if not exists devices (
            id integer primary key,
            uri text unique not null,
            chooser_text text not null,
            chooser_subtext text,
            is_preset boolean not null
        );

        create table if not exists frequencies (
            uri text unique not null,
            freq integer not null,
            constraint frequencies_devices_fk foreign key (uri) references devices(uri)
        );
    ]=]
    if res ~= hs.sqlite3.OK then
        error('error creating table: ' .. self.db:errmsg())
    end

    -- performance optimizations
    self.db:exec [[
        PRAGMA synchronous = OFF;
        PRAGMA journal_mode = MEMORY;
        PRAGMA temp_store = MEMORY;
        PRAGMA cache_size = -2000;
    ]]

    -- indexes
    local indexes = {
        'create index if not exists idx_devices_uri on devices(uri);',
        'create index if not exists idx_devices_is_preset on devices(is_preset);',
        'create index if not exists idx_frequencies_freq on frequencies(freq);',
    }
    for _, idx in ipairs(indexes) do
        res = self.db:exec(idx)
        if res ~= hs.sqlite3.OK then
            print('error creating index: ' .. self.db:errmsg())
        end
    end

    -- insert statement
    self.insertStmt = self.db:prepare [[
        insert or replace into devices
            (uri, chooser_text, chooser_subtext, is_preset)
        values
            (?, ?, ?, ?)
        ]]
    if not self.insertStmt then
        error('failed to prepare insert statement: ' .. self.db:errmsg())
    end

    -- update freq statement
    self.updateFreqStmt = self.db:prepare [[
        insert into frequencies (uri, freq)
        values (?, 1)
        on conflict(uri) do update
        set freq = freq + 1;
    ]]
    if not self.updateFreqStmt then
        error('failed to prepare update freq statement: ' .. self.db:errmsg())
    end

    self.connected = true
    log.d('connected to repo at ' .. self.path)
end

function repo:getDevices()
    local data = {}

    for row in self.db:nrows([[
    select
        d.uri,
        d.chooser_text as text,
        d.chooser_subtext as subText,
        f.freq,
        d.is_preset as isPreset
    from devices d
    left join frequencies f on f.uri = d.uri
    order by
        is_preset asc,
        freq desc
    ]]) do
        table.insert(data, row)
    end

    return data
end

function repo:insertDevices(objects)
    if #objects == 0 then return end

    self.db:exec('begin transaction')

    self.db:exec([[
        create temporary table if not exists temp_devices (
            uri text primary key,
            chooser_text text not null,
            chooser_subtext text,
            is_preset boolean not null
        ) without rowid
    ]])

    local tempInsert = self.db:prepare([[
        insert into temp_devices
            (uri, chooser_text, chooser_subtext, is_preset)
        values (?, ?, ?, ?)
    ]])

    for _, obj in ipairs(objects) do
        tempInsert:bind_values(
            obj.uri,
            obj.chooser_text,
            obj.chooser_subtext,
            obj.is_preset
        )
        tempInsert:step()
        tempInsert:reset()
    end

    tempInsert:finalize()

    self.db:exec([[
        update devices
        set
            chooser_text = (
                select t.chooser_text
                from temp_devices t
                where t.uri = devices.uri
            ),
            chooser_subtext = (
                select t.chooser_subtext
                from temp_devices t
                where t.uri = devices.uri
            ),
            is_preset = (
                select t.is_preset
                from temp_devices t
                where t.uri = devices.uri
            )
        where exists (
            select 1
            from temp_devices t
            where t.uri = devices.uri
        );

        insert into devices (uri, chooser_text, chooser_subtext, is_preset)
        select t.*
        from temp_devices t
        where not exists (
            select 1
            from devices d
            where d.uri = t.uri
        );
    ]])

    self.db:exec('drop table temp_devices')
    self.db:exec('commit')
end

function repo:updateFreq(uri)
    self.updateFreqStmt:bind_values(uri)
    local result = self.updateFreqStmt:step()
    if result ~= hs.sqlite3.DONE then
        error('error updating device freq: ' .. self.db:errmsg())
    end
    self.updateFreqStmt:reset()
end

function repo:close()
    if not self.connected then
        log.d('repo already disconnected')
        return
    end

    if self.insertStmt then
        self.insertStmt:finalize()
        self.insertStmt = nil
    end

    if self.updateFreqStmt then
        self.updateFreqStmt:finalize()
        self.updateFreqStmt = nil
    end

    if self.db then
        self.db:close()
        self.db = nil
    end

    self.connected = false
    log.d('disconnected from repo')
end

return repo
