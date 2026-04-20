require 'json'
require 'digest'
require 'securerandom'
require 'fileutils'
require 'tmpdir'

def uid
  SecureRandom.hex(10)
end

def asset(svg)
  md5 = Digest::MD5.hexdigest(svg)
  [md5, svg]
end

bg_game = <<~SVG
<svg xmlns="http://www.w3.org/2000/svg" width="480" height="360">
  <defs><linearGradient id="g" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0%" stop-color="#66BB6A"/><stop offset="100%" stop-color="#43A047"/>
  </linearGradient></defs>
  <rect width="480" height="360" fill="url(#g)"/>
  <rect y="300" width="480" height="60" fill="#388E3C"/>
  <text x="240" y="40" text-anchor="middle" font-size="28" fill="white" font-family="Arial" font-weight="bold">打地鼠</text>
</svg>
SVG

bg_over = <<~SVG
<svg xmlns="http://www.w3.org/2000/svg" width="480" height="360">
  <rect width="480" height="360" fill="#263238"/>
  <text x="240" y="150" text-anchor="middle" font-size="48" fill="#FF5722" font-family="Arial" font-weight="bold">游戏结束!</text>
  <text x="240" y="210" text-anchor="middle" font-size="20" fill="#CFD8DC" font-family="Arial">点击绿旗重新开始</text>
</svg>
SVG

def mole_hidden_svg(hole_outer, hole_inner)
  <<~SVG
  <svg xmlns="http://www.w3.org/2000/svg" width="110" height="40">
    <ellipse cx="55" cy="25" rx="50" ry="15" fill="#{hole_outer}"/>
    <ellipse cx="55" cy="22" rx="45" ry="12" fill="#{hole_inner}"/>
  </svg>
  SVG
end

def mole_showing_svg(hole_outer, hole_inner)
  <<~SVG
  <svg xmlns="http://www.w3.org/2000/svg" width="110" height="100">
    <ellipse cx="55" cy="45" rx="28" ry="35" fill="#8D6E63"/>
    <circle cx="55" cy="38" r="24" fill="#A1887F"/>
    <circle cx="45" cy="33" r="3" fill="#1A1A1A"/>
    <circle cx="67" cy="33" r="3" fill="#1A1A1A"/>
    <ellipse cx="55" cy="42" rx="6" ry="4" fill="#4E342E"/>
    <rect x="50" y="48" width="4" height="5" rx="1" fill="white"/>
    <rect x="56" y="48" width="4" height="5" rx="1" fill="white"/>
    <ellipse cx="55" cy="85" rx="50" ry="15" fill="#{hole_outer}"/>
    <ellipse cx="55" cy="82" rx="45" ry="12" fill="#{hole_inner}"/>
  </svg>
  SVG
end

def mole_hit_svg(hole_outer, hole_inner)
  <<~SVG
  <svg xmlns="http://www.w3.org/2000/svg" width="110" height="100">
    <ellipse cx="55" cy="45" rx="28" ry="35" fill="#8D6E63"/>
    <circle cx="55" cy="38" r="24" fill="#A1887F"/>
    <line x1="38" y1="27" x2="50" y2="37" stroke="#D32F2F" stroke-width="3"/>
    <line x1="50" y1="27" x2="38" y2="37" stroke="#D32F2F" stroke-width="3"/>
    <line x1="60" y1="27" x2="72" y2="37" stroke="#D32F2F" stroke-width="3"/>
    <line x1="72" y1="27" x2="60" y2="37" stroke="#D32F2F" stroke-width="3"/>
    <ellipse cx="55" cy="85" rx="50" ry="15" fill="#{hole_outer}"/>
    <ellipse cx="55" cy="82" rx="45" ry="12" fill="#{hole_inner}"/>
  </svg>
  SVG
end

def build_stage_blocks(score_vid, time_vid)
  s = {}
  %w[flag swbg1 swbg1m sets sett forever wait chgt if lt tvar swbg2 swbg2m stop].each { |k| s[k] = uid }
  {
    s['flag'] => {"opcode"=>"event_whenflagclicked","next"=>s['swbg1'],"parent"=>nil,"inputs"=>{},"fields"=>{},"shadow"=>false,"topLevel"=>true,"x"=>40,"y"=>40},
    s['swbg1'] => {"opcode"=>"looks_switchbackdropto","next"=>s['sets'],"parent"=>s['flag'],"inputs"=>{"BACKDROP"=>[1,s['swbg1m']]},"fields"=>{},"shadow"=>false,"topLevel"=>false},
    s['swbg1m'] => {"opcode"=>"looks_backdrops","next"=>nil,"parent"=>s['swbg1'],"inputs"=>{},"fields"=>{"BACKDROP"=>["game",nil]},"shadow"=>true,"topLevel"=>false},
    s['sets'] => {"opcode"=>"data_setvariableto","next"=>s['sett'],"parent"=>s['swbg1'],"inputs"=>{"VALUE"=>[1,[4,"0"]]},"fields"=>{"VARIABLE"=>["得分",score_vid]},"shadow"=>false,"topLevel"=>false},
    s['sett'] => {"opcode"=>"data_setvariableto","next"=>s['forever'],"parent"=>s['sets'],"inputs"=>{"VALUE"=>[1,[4,"30"]]},"fields"=>{"VARIABLE"=>["时间",time_vid]},"shadow"=>false,"topLevel"=>false},
    s['forever'] => {"opcode"=>"control_forever","next"=>nil,"parent"=>s['sett'],"inputs"=>{"SUBSTACK"=>[2,s['wait']]},"fields"=>{},"shadow"=>false,"topLevel"=>false},
    s['wait'] => {"opcode"=>"control_wait","next"=>s['chgt'],"parent"=>s['forever'],"inputs"=>{"DURATION"=>[1,[4,"1"]]},"fields"=>{},"shadow"=>false,"topLevel"=>false},
    s['chgt'] => {"opcode"=>"data_changevariableby","next"=>s['if'],"parent"=>s['wait'],"inputs"=>{"VALUE"=>[1,[4,"-1"]]},"fields"=>{"VARIABLE"=>["时间",time_vid]},"shadow"=>false,"topLevel"=>false},
    s['if'] => {"opcode"=>"control_if","next"=>nil,"parent"=>s['chgt'],"inputs"=>{"CONDITION"=>[2,s['lt']],"SUBSTACK"=>[2,s['swbg2']]},"fields"=>{},"shadow"=>false,"topLevel"=>false},
    s['lt'] => {"opcode"=>"operator_lt","next"=>nil,"parent"=>s['if'],"inputs"=>{"OPERAND1"=>[3,s['tvar'],[10,""]],"OPERAND2"=>[1,[10,"1"]]},"fields"=>{},"shadow"=>false,"topLevel"=>false},
    s['tvar'] => {"opcode"=>"data_variable","next"=>nil,"parent"=>s['lt'],"inputs"=>{},"fields"=>{"VARIABLE"=>["时间",time_vid]},"shadow"=>false,"topLevel"=>false},
    s['swbg2'] => {"opcode"=>"looks_switchbackdropto","next"=>s['stop'],"parent"=>s['if'],"inputs"=>{"BACKDROP"=>[1,s['swbg2m']]},"fields"=>{},"shadow"=>false,"topLevel"=>false},
    s['swbg2m'] => {"opcode"=>"looks_backdrops","next"=>nil,"parent"=>s['swbg2'],"inputs"=>{},"fields"=>{"BACKDROP"=>["gameover",nil]},"shadow"=>true,"topLevel"=>false},
    s['stop'] => {"opcode"=>"control_stop","next"=>nil,"parent"=>s['swbg2'],"inputs"=>{},"fields"=>{"STOP_OPTION"=>["all",nil]},"shadow"=>false,"topLevel"=>false,"mutation"=>{"tagName"=>"mutation","children"=>[],"hasnext"=>"false"}}
  }
end

def build_mole_blocks(score_vid, start_x, start_y, voice_key)
  m = {}
  %w[flag goto show sw0 sw0m forever w1 r1 sw1 sw1m w2 if1 eq1 cn1 sw2 sw2m click if2 eq2 cn2 chg swh swhm w3 swb swbm
     key ifk eqk cnk chgk swhk swhkm w3k swbk swbkm].each { |k| m[k] = uid }
  {
    m['flag'] => {"opcode"=>"event_whenflagclicked","next"=>m['goto'],"parent"=>nil,"inputs"=>{},"fields"=>{},"shadow"=>false,"topLevel"=>true,"x"=>40,"y"=>40},
    m['goto'] => {"opcode"=>"motion_gotoxy","next"=>m['show'],"parent"=>m['flag'],"inputs"=>{"X"=>[1,[4,start_x.to_s]],"Y"=>[1,[4,start_y.to_s]]},"fields"=>{},"shadow"=>false,"topLevel"=>false},
    m['show'] => {"opcode"=>"looks_show","next"=>m['sw0'],"parent"=>m['goto'],"inputs"=>{},"fields"=>{},"shadow"=>false,"topLevel"=>false},
    m['sw0'] => {"opcode"=>"looks_switchcostumeto","next"=>m['forever'],"parent"=>m['show'],"inputs"=>{"COSTUME"=>[1,m['sw0m']]},"fields"=>{},"shadow"=>false,"topLevel"=>false},
    m['sw0m'] => {"opcode"=>"looks_costume","next"=>nil,"parent"=>m['sw0'],"inputs"=>{},"fields"=>{"COSTUME"=>["hidden",nil]},"shadow"=>true,"topLevel"=>false},
    m['forever'] => {"opcode"=>"control_forever","next"=>nil,"parent"=>m['sw0'],"inputs"=>{"SUBSTACK"=>[2,m['w1']]},"fields"=>{},"shadow"=>false,"topLevel"=>false},
    m['w1'] => {"opcode"=>"control_wait","next"=>m['sw1'],"parent"=>m['forever'],"inputs"=>{"DURATION"=>[3,m['r1'],[4,"0.5"]]},"fields"=>{},"shadow"=>false,"topLevel"=>false},
    m['r1'] => {"opcode"=>"operator_random","next"=>nil,"parent"=>m['w1'],"inputs"=>{"FROM"=>[1,[4,"0.4"]],"TO"=>[1,[4,"1.3"]]},"fields"=>{},"shadow"=>false,"topLevel"=>false},
    m['sw1'] => {"opcode"=>"looks_switchcostumeto","next"=>m['w2'],"parent"=>m['w1'],"inputs"=>{"COSTUME"=>[1,m['sw1m']]},"fields"=>{},"shadow"=>false,"topLevel"=>false},
    m['sw1m'] => {"opcode"=>"looks_costume","next"=>nil,"parent"=>m['sw1'],"inputs"=>{},"fields"=>{"COSTUME"=>["showing",nil]},"shadow"=>true,"topLevel"=>false},
    m['w2'] => {"opcode"=>"control_wait","next"=>m['if1'],"parent"=>m['sw1'],"inputs"=>{"DURATION"=>[1,[4,"1"]]},"fields"=>{},"shadow"=>false,"topLevel"=>false},
    m['if1'] => {"opcode"=>"control_if","next"=>nil,"parent"=>m['w2'],"inputs"=>{"CONDITION"=>[2,m['eq1']],"SUBSTACK"=>[2,m['sw2']]},"fields"=>{},"shadow"=>false,"topLevel"=>false},
    m['eq1'] => {"opcode"=>"operator_equals","next"=>nil,"parent"=>m['if1'],"inputs"=>{"OPERAND1"=>[3,m['cn1'],[10,""]],"OPERAND2"=>[1,[10,"showing"]]},"fields"=>{},"shadow"=>false,"topLevel"=>false},
    m['cn1'] => {"opcode"=>"looks_costumenumbername","next"=>nil,"parent"=>m['eq1'],"inputs"=>{},"fields"=>{"NUMBER_NAME"=>["name",nil]},"shadow"=>false,"topLevel"=>false},
    m['sw2'] => {"opcode"=>"looks_switchcostumeto","next"=>nil,"parent"=>m['if1'],"inputs"=>{"COSTUME"=>[1,m['sw2m']]},"fields"=>{},"shadow"=>false,"topLevel"=>false},
    m['sw2m'] => {"opcode"=>"looks_costume","next"=>nil,"parent"=>m['sw2'],"inputs"=>{},"fields"=>{"COSTUME"=>["hidden",nil]},"shadow"=>true,"topLevel"=>false},
    m['click'] => {"opcode"=>"event_whenthisspriteclicked","next"=>m['if2'],"parent"=>nil,"inputs"=>{},"fields"=>{},"shadow"=>false,"topLevel"=>true,"x"=>380,"y"=>40},
    m['if2'] => {"opcode"=>"control_if","next"=>nil,"parent"=>m['click'],"inputs"=>{"CONDITION"=>[2,m['eq2']],"SUBSTACK"=>[2,m['chg']]},"fields"=>{},"shadow"=>false,"topLevel"=>false},
    m['eq2'] => {"opcode"=>"operator_equals","next"=>nil,"parent"=>m['if2'],"inputs"=>{"OPERAND1"=>[3,m['cn2'],[10,""]],"OPERAND2"=>[1,[10,"showing"]]},"fields"=>{},"shadow"=>false,"topLevel"=>false},
    m['cn2'] => {"opcode"=>"looks_costumenumbername","next"=>nil,"parent"=>m['eq2'],"inputs"=>{},"fields"=>{"NUMBER_NAME"=>["name",nil]},"shadow"=>false,"topLevel"=>false},
    m['chg'] => {"opcode"=>"data_changevariableby","next"=>m['swh'],"parent"=>m['if2'],"inputs"=>{"VALUE"=>[1,[4,"1"]]},"fields"=>{"VARIABLE"=>["得分",score_vid]},"shadow"=>false,"topLevel"=>false},
    m['swh'] => {"opcode"=>"looks_switchcostumeto","next"=>m['w3'],"parent"=>m['chg'],"inputs"=>{"COSTUME"=>[1,m['swhm']]},"fields"=>{},"shadow"=>false,"topLevel"=>false},
    m['swhm'] => {"opcode"=>"looks_costume","next"=>nil,"parent"=>m['swh'],"inputs"=>{},"fields"=>{"COSTUME"=>["hit",nil]},"shadow"=>true,"topLevel"=>false},
    m['w3'] => {"opcode"=>"control_wait","next"=>m['swb'],"parent"=>m['swh'],"inputs"=>{"DURATION"=>[1,[4,"0.15"]]},"fields"=>{},"shadow"=>false,"topLevel"=>false},
    m['swb'] => {"opcode"=>"looks_switchcostumeto","next"=>nil,"parent"=>m['w3'],"inputs"=>{"COSTUME"=>[1,m['swbm']]},"fields"=>{},"shadow"=>false,"topLevel"=>false},
    m['swbm'] => {"opcode"=>"looks_costume","next"=>nil,"parent"=>m['swb'],"inputs"=>{},"fields"=>{"COSTUME"=>["hidden",nil]},"shadow"=>true,"topLevel"=>false},
    m['key'] => {"opcode"=>"event_whenkeypressed","next"=>m['ifk'],"parent"=>nil,"inputs"=>{},"fields"=>{"KEY_OPTION"=>[voice_key,nil]},"shadow"=>false,"topLevel"=>true,"x"=>380,"y"=>220},
    m['ifk'] => {"opcode"=>"control_if","next"=>nil,"parent"=>m['key'],"inputs"=>{"CONDITION"=>[2,m['eqk']],"SUBSTACK"=>[2,m['chgk']]},"fields"=>{},"shadow"=>false,"topLevel"=>false},
    m['eqk'] => {"opcode"=>"operator_equals","next"=>nil,"parent"=>m['ifk'],"inputs"=>{"OPERAND1"=>[3,m['cnk'],[10,""]],"OPERAND2"=>[1,[10,"showing"]]},"fields"=>{},"shadow"=>false,"topLevel"=>false},
    m['cnk'] => {"opcode"=>"looks_costumenumbername","next"=>nil,"parent"=>m['eqk'],"inputs"=>{},"fields"=>{"NUMBER_NAME"=>["name",nil]},"shadow"=>false,"topLevel"=>false},
    m['chgk'] => {"opcode"=>"data_changevariableby","next"=>m['swhk'],"parent"=>m['ifk'],"inputs"=>{"VALUE"=>[1,[4,"1"]]},"fields"=>{"VARIABLE"=>["得分",score_vid]},"shadow"=>false,"topLevel"=>false},
    m['swhk'] => {"opcode"=>"looks_switchcostumeto","next"=>m['w3k'],"parent"=>m['chgk'],"inputs"=>{"COSTUME"=>[1,m['swhkm']]},"fields"=>{},"shadow"=>false,"topLevel"=>false},
    m['swhkm'] => {"opcode"=>"looks_costume","next"=>nil,"parent"=>m['swhk'],"inputs"=>{},"fields"=>{"COSTUME"=>["hit",nil]},"shadow"=>true,"topLevel"=>false},
    m['w3k'] => {"opcode"=>"control_wait","next"=>m['swbk'],"parent"=>m['swhk'],"inputs"=>{"DURATION"=>[1,[4,"0.15"]]},"fields"=>{},"shadow"=>false,"topLevel"=>false},
    m['swbk'] => {"opcode"=>"looks_switchcostumeto","next"=>nil,"parent"=>m['w3k'],"inputs"=>{"COSTUME"=>[1,m['swbkm']]},"fields"=>{},"shadow"=>false,"topLevel"=>false},
    m['swbkm'] => {"opcode"=>"looks_costume","next"=>nil,"parent"=>m['swbk'],"inputs"=>{},"fields"=>{"COSTUME"=>["hidden",nil]},"shadow"=>true,"topLevel"=>false}
  }
end

def build_mole_target(name:, x:, y:, layer:, score_vid:, voice_key:, hidden_asset:, showing_asset:, hit_asset:)
  {
    "isStage"=>false,
    "name"=>name,
    "variables"=>{}, "lists"=>{}, "broadcasts"=>{}, "comments"=>{},
    "blocks"=>build_mole_blocks(score_vid, x, y, voice_key),
    "currentCostume"=>0,
    "costumes"=>[
      {"assetId"=>hidden_asset[:md5],"name"=>"hidden","bitmapResolution"=>1,"md5ext"=>"#{hidden_asset[:md5]}.svg","dataFormat"=>"svg","rotationCenterX"=>55,"rotationCenterY"=>20},
      {"assetId"=>showing_asset[:md5],"name"=>"showing","bitmapResolution"=>1,"md5ext"=>"#{showing_asset[:md5]}.svg","dataFormat"=>"svg","rotationCenterX"=>55,"rotationCenterY"=>80},
      {"assetId"=>hit_asset[:md5],"name"=>"hit","bitmapResolution"=>1,"md5ext"=>"#{hit_asset[:md5]}.svg","dataFormat"=>"svg","rotationCenterX"=>55,"rotationCenterY"=>80}
    ],
    "sounds"=>[], "volume"=>100, "layerOrder"=>layer,
    "visible"=>true, "x"=>x, "y"=>y, "size"=>100,
    "direction"=>90, "draggable"=>false, "rotationStyle"=>"all around"
  }
end

score_vid = uid
time_vid = uid

bg1_md5, bg1_svg = asset(bg_game)
bg2_md5, bg2_svg = asset(bg_over)
hole_configs = [
  { name: 'MoleWhite', x: 0, y: 90, outer: '#ECEFF1', inner: '#FFFFFF', voice_key: 'w' },
  { name: 'MoleRed', x: -120, y: -70, outer: '#B71C1C', inner: '#E53935', voice_key: 'r' },
  { name: 'MoleGreen', x: 120, y: -70, outer: '#1B5E20', inner: '#43A047', voice_key: 'g' }
]

mole_assets = hole_configs.map do |cfg|
  h_md5, h_svg = asset(mole_hidden_svg(cfg[:outer], cfg[:inner]))
  s_md5, s_svg = asset(mole_showing_svg(cfg[:outer], cfg[:inner]))
  k_md5, k_svg = asset(mole_hit_svg(cfg[:outer], cfg[:inner]))
  cfg.merge(
    hidden: { md5: h_md5, svg: h_svg },
    showing: { md5: s_md5, svg: s_svg },
    hit: { md5: k_md5, svg: k_svg }
  )
end

project = {
  "targets" => [
    {
      "isStage"=>true,
      "name"=>"Stage",
      "variables"=>{score_vid=>["得分",0], time_vid=>["时间",30]},
      "lists"=>{},"broadcasts"=>{},"comments"=>{},
      "blocks"=>build_stage_blocks(score_vid, time_vid),
      "currentCostume"=>0,
      "costumes"=>[
        {"assetId"=>bg1_md5,"name"=>"game","bitmapResolution"=>1,"md5ext"=>"#{bg1_md5}.svg","dataFormat"=>"svg","rotationCenterX"=>240,"rotationCenterY"=>180},
        {"assetId"=>bg2_md5,"name"=>"gameover","bitmapResolution"=>1,"md5ext"=>"#{bg2_md5}.svg","dataFormat"=>"svg","rotationCenterX"=>240,"rotationCenterY"=>180}
      ],
      "sounds"=>[],"volume"=>100,"layerOrder"=>0,
      "tempo"=>60,"videoTransparency"=>50,"videoState"=>"off","textToSpeechLanguage"=>nil
    }
  ] + mole_assets.each_with_index.map do |cfg, idx|
    build_mole_target(
      name: cfg[:name],
      x: cfg[:x],
      y: cfg[:y],
      layer: idx + 1,
      score_vid: score_vid,
      voice_key: cfg[:voice_key],
      hidden_asset: cfg[:hidden],
      showing_asset: cfg[:showing],
      hit_asset: cfg[:hit]
    )
  end,
  "monitors" => [
    {"id"=>score_vid,"mode"=>"default","opcode"=>"data_variable","params"=>{"VARIABLE"=>"得分"},"spriteName"=>nil,"value"=>0,"width"=>0,"height"=>0,"x"=>5,"y"=>5,"visible"=>true,"sliderMin"=>0,"sliderMax"=>100,"isDiscrete"=>true},
    {"id"=>time_vid,"mode"=>"default","opcode"=>"data_variable","params"=>{"VARIABLE"=>"时间"},"spriteName"=>nil,"value"=>30,"width"=>0,"height"=>0,"x"=>5,"y"=>35,"visible"=>true,"sliderMin"=>0,"sliderMax"=>100,"isDiscrete"=>true}
  ],
  "extensions"=>[],
  "meta"=>{"semver"=>"3.0.0","vm"=>"2.0.0","agent"=>""}
}

out_dir = File.expand_path('~/Downloads/my-scratch-project')
FileUtils.mkdir_p(out_dir)
out_file = File.join(out_dir, 'whack-a-mole.sb3')

Dir.mktmpdir('scratch-gen') do |tmp|
  File.write(File.join(tmp, 'project.json'), JSON.generate(project))
  assets_to_write = {
    "#{bg1_md5}.svg" => bg1_svg,
    "#{bg2_md5}.svg" => bg2_svg
  }
  mole_assets.each do |cfg|
    assets_to_write["#{cfg[:hidden][:md5]}.svg"] = cfg[:hidden][:svg]
    assets_to_write["#{cfg[:showing][:md5]}.svg"] = cfg[:showing][:svg]
    assets_to_write["#{cfg[:hit][:md5]}.svg"] = cfg[:hit][:svg]
  end
  assets_to_write.each { |name, data| File.write(File.join(tmp, name), data) }

  Dir.chdir(tmp) do
    system("zip -q -r '#{out_file}' .") or abort('zip failed')
  end
end

puts "✅ 已生成: #{out_file}"
puts "大小: #{File.size(out_file)} bytes"
