import discord
from discord.ext import tasks, commands
import asyncio
import os
import sys

# ---- INTENTS ----
intents = discord.Intents.default()
intents.guilds = True
intents.members = True
intents.presences = True
intents.message_content = True

bot = commands.Bot(command_prefix="!", intents=intents)

# ---- CONFIG ----
TOKEN = ""  # ⚠️ pack hier nur EIN Token rein!
GUILD_ID = 1259197351931678941

# --- Channel IDs ---
CHANNEL_RÄNGE = 1413179867909849129
CHANNEL_LEVEL_REWARDS = 1413179869335916649
CHANNEL_ROLLEN = 1413179870745465055

BOTS_CHANNEL_ID = 1413192240213262478
MEMBERS_CHANNEL_ID = 1413192213332099082
ONLINE_CHANNEL_ID = 1413192183212671096

# --- Phasmo Role System ---
PHASMO_ROLE_CHANNEL_ID = 1413337544883572828
PHASMO_ROLE_ID = 1413179818274590855

# --- Platform Role System ---
PLATFORMS_CHANNEL_ID = 1413337570804371597
SWITCH_ROLE_ID = 1413179835991195660
PC_ROLE_ID = 1413179831562145913
XBOX_ROLE_ID = 1413179832896061570
MOBILE_ROLE_ID = 1413179829909586102
PLAYSTATION_ROLE_ID = 1413179834728841370

# ---- Rollen + Emojis ----
roles_ränge = {
    "OWNER": 1413179794970906664,
    
    "CO OWNER": 1413179796220809237,
    
    "Dritt Owner": 1413179797244481700,
    
    "Admin": 1413179798506963036,
    
    "Test Admin": 1413321526391869490,
    
    "Supporter": 1413179823328858164,
    
    "Vize": 1413179801463685271,
    
    "PHASMO HELPER": 1413179822313832458
    
}

emoji_ränge = {
    "OWNER": "👑",
    
    "CO OWNER": "🏆",
    
    "Dritt Owner": "☝️",
    
    "Admin": "🛡",
    
    "Test Admin": "🧑‍🎓",
    
    "Supporter": "🔊",
    
    "Vize": "🎩",
    
    "PHASMO HELPER": "🎃"
}

rollen_text = """


𝐎𝐰𝐧𝐞𝐫  👑

𝐂𝐨 𝐎𝐰𝐧𝐞𝐫  🏆

𝐃𝐫𝐢𝐭𝐭 𝐎𝐰𝐧𝐞𝐫  ☝️

𝐀𝐝𝐦𝐢𝐧  🛡

𝐓𝐞𝐬𝐭 𝐀𝐝𝐦𝐢𝐧  🧑‍🎓

𝐒𝐮𝐩𝐩𝐨𝐫𝐭𝐞𝐫  🔊

𝐕𝐢𝐳𝐞 𝐀𝐧𝐟ü𝐫𝐞𝐫  🎩

𝐏𝐇𝐀𝐒𝐌𝐎 𝐇𝐄𝐋𝐏𝐄𝐑  🎃

𝐎𝐆  👨‍🦳

𝐄𝐡𝐫𝐞𝐧 𝐦𝐚𝐧  🤲

𝐅𝐮𝐥𝐥 𝐌𝐞𝐦𝐛𝐞𝐫  👤

𝐌𝐚𝐜𝐡𝐞𝐫  😎

𝐌𝐢𝐭𝐠𝐥𝐢𝐞𝐝𝐞𝐫  😀

𝐓𝐨𝐢𝐥𝐞𝐭𝐭𝐞𝐧 𝐏𝐮𝐭𝐳𝐞𝐫  🚽

"""

level_rewards_text = """
𝐋𝐞𝐯𝐞𝐥 𝐑𝐞𝐰𝐚𝐫𝐝𝐬 𝐄𝐫𝐡ä𝐥𝐭𝐬𝐭 𝐝𝐮 𝐰𝐞𝐧𝐧 𝐝𝐮 𝐍𝐚𝐫𝐢𝐜𝐡𝐭𝐞𝐧
𝐬𝐜𝐡𝐫𝐞𝐢𝐛𝐬𝐭 𝐨𝐝𝐞𝐫 𝐋ä𝐧𝐠𝐞𝐫 𝐈𝐧 𝐓𝐚𝐥𝐤𝐬 𝐛𝐢𝐬𝐭 🎁
-----------------------------------------------------------

𝐌𝐚𝐜𝐡𝐞𝐫 = LEVEL 5

𝐅𝐮𝐥𝐥 𝐌𝐞𝐦𝐛𝐞𝐫 = LEVEL 15

𝐄𝐡𝐫𝐞𝐧 𝐦𝐚𝐧 = LEVEL 25

𝐎𝐆 = LEVEL 35

"""

EMBED_COLOR = 0x261F6A

# --- Phasmo Role Button View ---
class PhasmoRoleView(discord.ui.View):
    def __init__(self):
        super().__init__(timeout=None)

    @discord.ui.button(label="🟣", style=discord.ButtonStyle.secondary, custom_id="phasmo_role_button")
    async def get_phasmo_role(self, interaction: discord.Interaction, button: discord.ui.Button):
        try:
            if not isinstance(interaction.user, discord.Member):
                await interaction.response.send_message("❌ Nur Server-Mitglieder können Rollen erhalten.", ephemeral=True)
                return
                
            guild = interaction.guild
            if not guild:
                await interaction.response.send_message("❌ Guild nicht gefunden!", ephemeral=True)
                return
                
            phasmo_role = guild.get_role(PHASMO_ROLE_ID)
            if not phasmo_role:
                await interaction.response.send_message("❌ Phasmo Rolle nicht gefunden!", ephemeral=True)
                return
            
            member = interaction.user
            if phasmo_role in member.roles:
                await interaction.response.send_message("✅ Du hast die Phasmo Rolle bereits!", ephemeral=True)
            else:
                await member.add_roles(phasmo_role)
                await interaction.response.send_message("🟣 Phasmo Rolle erfolgreich erhalten! Willkommen im Phasmo Team!", ephemeral=True)
                print(f"✅ {member.display_name} hat die Phasmo Rolle erhalten!")
                
        except Exception as e:
            print(f"❌ Fehler beim Vergeben der Phasmo Rolle: {e}")
            try:
                await interaction.response.send_message("❌ Ein Fehler ist aufgetreten. Bitte versuche es erneut.", ephemeral=True)
            except:
                pass

# ---- Platform Role View ----
class PlatformsRoleView(discord.ui.View):
    def __init__(self):
        super().__init__(timeout=None)

    @discord.ui.button(label="🔴", style=discord.ButtonStyle.secondary, custom_id="switch_role_button")
    async def get_switch_role(self, interaction: discord.Interaction, button: discord.ui.Button):
        await self.handle_platform_role(interaction, SWITCH_ROLE_ID, "Switch")

    @discord.ui.button(label="🟡", style=discord.ButtonStyle.secondary, custom_id="pc_role_button")
    async def get_pc_role(self, interaction: discord.Interaction, button: discord.ui.Button):
        await self.handle_platform_role(interaction, PC_ROLE_ID, "PC")

    @discord.ui.button(label="🟢", style=discord.ButtonStyle.secondary, custom_id="xbox_role_button")
    async def get_xbox_role(self, interaction: discord.Interaction, button: discord.ui.Button):
        await self.handle_platform_role(interaction, XBOX_ROLE_ID, "Xbox")

    @discord.ui.button(label="🟣", style=discord.ButtonStyle.secondary, custom_id="mobile_role_button")
    async def get_mobile_role(self, interaction: discord.Interaction, button: discord.ui.Button):
        await self.handle_platform_role(interaction, MOBILE_ROLE_ID, "Mobile")

    @discord.ui.button(label="🔵", style=discord.ButtonStyle.secondary, custom_id="playstation_role_button")
    async def get_playstation_role(self, interaction: discord.Interaction, button: discord.ui.Button):
        await self.handle_platform_role(interaction, PLAYSTATION_ROLE_ID, "PlayStation")

    async def handle_platform_role(self, interaction: discord.Interaction, role_id: int, platform_name: str):
        try:
            if not isinstance(interaction.user, discord.Member):
                await interaction.response.send_message("❌ Nur Server-Mitglieder können Rollen erhalten.", ephemeral=True)
                return
                
            guild = interaction.guild
            if not guild:
                await interaction.response.send_message("❌ Guild nicht gefunden!", ephemeral=True)
                return
                
            platform_role = guild.get_role(role_id)
            if not platform_role:
                await interaction.response.send_message(f"❌ {platform_name} Rolle nicht gefunden!", ephemeral=True)
                return

            # Toggle the role - add if user doesn't have it, remove if they do
            if platform_role in interaction.user.roles:
                await interaction.user.remove_roles(platform_role)
                await interaction.response.send_message(f"❌ {platform_name} Rolle entfernt!", ephemeral=True)
                print(f"✅ {interaction.user.name} hat die {platform_name} Rolle verloren!")
            else:
                await interaction.user.add_roles(platform_role)
                await interaction.response.send_message(f"✅ {platform_name} Rolle erhalten!", ephemeral=True)
                print(f"✅ {interaction.user.name} hat die {platform_name} Rolle erhalten!")

        except Exception as e:
            await interaction.response.send_message(f"❌ Ein Fehler ist aufgetreten: {str(e)}", ephemeral=True)
            print(f"❌ {platform_name} Role Error: {e}")

def build_embed(title, description):
    return discord.Embed(title=title, description=description, color=EMBED_COLOR)

def build_role_list_embed(guild, roles_dict, emoji_dict, title):
    text = ""
    for name, role_id in roles_dict.items():
        role = guild.get_role(role_id)
        if not role:
            continue
        members = [member.display_name for member in role.members]
        members_text = " / ".join(members) if members else "-"
        emoji = emoji_dict.get(name, "")
        display_name = f"**{name} {emoji}**" if emoji else f"**{name}**"
        text += f"{display_name}\n{members_text}\n\n"
    return build_embed(title, text)

# ---- Embed Refresh ----
async def refresh_bot():
    print("🔄 Rollen-Refresh läuft...")
    guild = bot.get_guild(GUILD_ID)

    if not guild:
        print("❌ Guild nicht gefunden")
        return

    channel_ränge = guild.get_channel(CHANNEL_RÄNGE)
    channel_level = guild.get_channel(CHANNEL_LEVEL_REWARDS)
    channel_rollen = guild.get_channel(CHANNEL_ROLLEN)

    if not channel_ränge or not channel_level or not channel_rollen:
        print("❌ Channels nicht gefunden")
        return

    # Level Rewards aktualisieren
    messages_level = [msg async for msg in channel_level.history(limit=10)]
    msg_level = next((msg for msg in messages_level if msg.author == bot.user), None)
    if not msg_level:
        await channel_level.send(embed=build_embed("Level Rewards", level_rewards_text))
    else:
        await msg_level.edit(embed=build_embed("Level Rewards", level_rewards_text))

    # Ränge aktualisieren
    messages_ränge = [msg async for msg in channel_ränge.history(limit=10)]
    msg_ränge = next((msg for msg in messages_ränge if msg.author == bot.user), None)
    if msg_ränge:
        await msg_ränge.edit(embed=build_role_list_embed(guild, roles_ränge, emoji_ränge, "Ränge"))
    else:
        await channel_ränge.send(embed=build_role_list_embed(guild, roles_ränge, emoji_ränge, "Ränge"))

    # Rollen aktualisieren
    messages_rollen = [msg async for msg in channel_rollen.history(limit=10)]
    msg_rollen = next((msg for msg in messages_rollen if msg.author == bot.user), None)
    if msg_rollen:
        await msg_rollen.edit(embed=build_embed("Rollen", rollen_text))
    else:
        await channel_rollen.send(embed=build_embed("Rollen", rollen_text))

    print("✅ Rollen-Refresh fertig")

# ---- Phasmo Role Message ----
async def send_phasmo_message():
    print("🔄 Phasmo-Nachricht wird erstellt...")
    guild = bot.get_guild(GUILD_ID)
    
    if not guild:
        print("❌ Guild nicht gefunden")
        return
        
    phasmo_channel = guild.get_channel(PHASMO_ROLE_CHANNEL_ID)
    if not phasmo_channel:
        print("❌ Phasmo Channel nicht gefunden")
        return
    
    # Check if channel is a text channel
    if not isinstance(phasmo_channel, discord.TextChannel):
        print("❌ Phasmo Channel muss ein Text-Channel sein!")
        return
    
    # Suche nach bestehender Phasmo-Nachricht
    existing_message = None
    async for message in phasmo_channel.history(limit=20):
        if (message.author == bot.user and message.embeds and 
            len(message.embeds) > 0 and message.embeds[0].description and 
            "𝐏𝐡𝐚𝐬𝐦𝐨 𝐑𝐨𝐥𝐥𝐞" in message.embeds[0].description):
            existing_message = message
            break
    
    # Fancy Phasmo Embed mit GIF
    embed = discord.Embed(
        title="𝐏𝐡𝐚𝐬𝐦𝐨 - 𝐑𝐨𝐥𝐥𝐞",
        description="𝐊𝐥𝐢𝐜𝐤𝐞 𝐚𝐮𝐟 𝐝𝐚𝐬 🟣 𝐔𝐦 𝐃𝐢𝐞 𝐏𝐡𝐚𝐬𝐦𝐨 𝐑𝐨𝐥𝐥𝐞 𝐳𝐮 𝐄𝐫𝐡𝐚𝐥𝐭𝐞𝐧 𝐔𝐦 𝐰𝐞𝐢𝐭𝐞𝐫𝐞 𝐂𝐡𝐚𝐧𝐧𝐞𝐥 𝐳𝐮 𝐒𝐞𝐡𝐞𝐧",
        color=0x9d4edd  # Lila Farbe passend zu Phasmo
    )
    
    # Bot-Avatar neben dem Titel hinzufügen
    if bot.user and bot.user.avatar:
        embed.set_author(
            name="Chillounge von GLÜHFIX",
            icon_url=bot.user.avatar.url
        )
    else:
        embed.set_author(name="Chillounge von GLÜHFIX")
    
    # Das neue geile Phasmo GIF ganz unten
    embed.set_image(url="https://share.creavite.co/68ba3df174e175dfbf0701c0.gif")
    embed.set_footer(text="👻 Willkommen im Phasmo Team!")
    
    # Bearbeite bestehende Nachricht oder sende neue
    if existing_message:
        await existing_message.edit(embed=embed, view=PhasmoRoleView())
        print("✅ Phasmo-Nachricht aktualisiert!")
    else:
        await phasmo_channel.send(embed=embed, view=PhasmoRoleView())
        print("✅ Neue Phasmo-Nachricht gesendet!")

# ---- Platforms Role Message ----
async def send_platforms_message():
    print("🔄 Plattformen-Nachricht wird erstellt...")
    guild = bot.get_guild(GUILD_ID)
    
    if not guild:
        print("❌ Guild nicht gefunden")
        return
        
    platforms_channel = guild.get_channel(PLATFORMS_CHANNEL_ID)
    if not platforms_channel:
        print("❌ Plattformen Channel nicht gefunden")
        return
    
    # Check if channel is a text channel
    if not isinstance(platforms_channel, discord.TextChannel):
        print("❌ Plattformen Channel muss ein Text-Channel sein!")
        return
    
    # Suche nach bestehender Plattformen-Nachricht
    existing_message = None
    async for message in platforms_channel.history(limit=20):
        if (message.author == bot.user and message.embeds and 
            len(message.embeds) > 0 and message.embeds[0].title and 
            "𝐏𝐥𝐚𝐭𝐭𝐅𝐨𝐫𝐦𝐞𝐧" in message.embeds[0].title):
            existing_message = message
            break
    
    # Fancy Plattformen Embed
    embed = discord.Embed(
        title="𝐏𝐥𝐚𝐭𝐭𝐅𝐨𝐫𝐦𝐞𝐧",
        description="𝐃𝐫ü𝐜𝐤𝐭 𝐀𝐮𝐟 𝐄𝐢𝐧𝐞𝐫 𝐝𝐢𝐞𝐬𝐞𝐫 𝐙𝐞𝐢𝐜𝐡𝐞𝐧 𝐔𝐦 𝐳𝐮 𝐙𝐞𝐢𝐠𝐞𝐧 𝐚𝐮𝐟 𝐰𝐞𝐥𝐜𝐡𝐞𝐧 𝐝𝐞𝐫 𝐏𝐥𝐚𝐭𝐭𝐅𝐨𝐫𝐦𝐞𝐧 𝐢𝐡𝐫 𝐮𝐧𝐭𝐞𝐫𝐰𝐞𝐠𝐬 𝐬𝐞𝐢𝐭\n\n𝐒𝐰𝐢𝐭𝐜𝐡 🔴\n\n𝐏𝐜 🟡\n\n𝐗𝐛𝐨𝐱 🟢\n\n𝐌𝐨𝐛𝐢𝐥𝐞 🟣\n\n𝐏𝐥𝐚𝐲𝐬𝐭𝐚𝐭𝐢𝐨𝐧 🔵",
        color=0x00ff88  # Grüne Farbe für Gaming
    )
    
    # Bot-Avatar neben dem Titel hinzufügen
    if bot.user and bot.user.avatar:
        embed.set_author(
            name="Chillounge von GLÜHFIX",
            icon_url=bot.user.avatar.url
        )
    else:
        embed.set_author(name="Chillounge von GLÜHFIX")
    
    embed.set_footer(text="🎮 Zeige deine Gaming-Plattformen!")
    
    # Bearbeite bestehende Nachricht oder sende neue
    if existing_message:
        await existing_message.edit(embed=embed, view=PlatformsRoleView())
        print("✅ Plattformen-Nachricht aktualisiert!")
    else:
        await platforms_channel.send(embed=embed, view=PlatformsRoleView())
        print("✅ Neue Plattformen-Nachricht gesendet!")

# ---- Voice Channel Stats ----
@tasks.loop(minutes=2)
async def update_stats():
    guild = bot.get_guild(GUILD_ID)
    if not guild:
        return

    bot_count = sum(1 for m in guild.members if m.bot)
    member_count = guild.member_count
    online_count = sum(1 for m in guild.members if m.status != discord.Status.offline and not m.bot)  # Nur echte Spieler, keine Bots

    bots_channel = guild.get_channel(BOTS_CHANNEL_ID)
    members_channel = guild.get_channel(MEMBERS_CHANNEL_ID)
    online_channel = guild.get_channel(ONLINE_CHANNEL_ID)

    await bots_channel.edit(name=f"🤖 • Bots {bot_count}")
    await members_channel.edit(name=f"🖐️ • Mitglieder {member_count}")
    await online_channel.edit(name=f"🟢 • Online {online_count}")
    
    # Zeige nächsten Restart Zeitpunkt an
    import datetime
    next_run = datetime.datetime.now() + datetime.timedelta(minutes=2)
    print(f"📊 Stats aktualisiert - Nächster Update: {next_run.strftime('%H:%M:%S')}")

# ---- On Ready ----
@bot.event
async def on_ready():
    print(f"✅ Bot ist online als {bot.user}")
    await refresh_bot()
    await send_phasmo_message()
    await send_platforms_message()
    update_stats.start()

# ---- Start ----
bot.run(TOKEN)
