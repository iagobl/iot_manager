import { createClient } from 'jsr:@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type',
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  if (request.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), {
      status: 405,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }

  try {
    const body = await request.json()
    const deviceId = String(body?.device_id ?? '').trim()
    if (!deviceId) {
      return new Response(JSON.stringify({ error: 'device_id is required' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL')
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
    if (!supabaseUrl || !serviceRoleKey) {
      return new Response(JSON.stringify({ error: 'Missing Supabase env vars' }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const admin = createClient(supabaseUrl, serviceRoleKey)

    const { data: device, error: deviceError } = await admin
      .from('devices')
      .select('id')
      .eq('id', deviceId)
      .maybeSingle()

    if (deviceError || !device) {
      return new Response(JSON.stringify({ error: 'Unknown device_id' }), {
        status: 404,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const powerW = Number(body?.power_w ?? 0)
    const voltageV = Number(body?.voltage_v ?? 0)
    const currentA = Number(body?.current_a ?? 0)
    const energyWh = Number(body?.energy_wh ?? 0)

    const meta = {
      ...(typeof body?.meta === 'object' && body.meta !== null ? body.meta : {}),
      source: body?.source ?? 'shelly_script',
      is_on: body?.is_on ?? null,
      device_model: body?.device_model ?? null,
      script_name: body?.script_name ?? null,
      shelly_id: body?.shelly_id ?? null,
      received_at: new Date().toISOString(),
    }

    const { error: insertError } = await admin.from('readings').insert({
      device_id: deviceId,
      ts: new Date().toISOString(),
      power_w: Number.isFinite(powerW) ? powerW : 0,
      voltage_v: Number.isFinite(voltageV) ? voltageV : 0,
      current_a: Number.isFinite(currentA) ? currentA : 0,
      energy_wh: Number.isFinite(energyWh) ? energyWh : 0,
      meta,
    })

    if (insertError) {
      return new Response(JSON.stringify({ error: insertError.message }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    return new Response(JSON.stringify({ ok: true }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  } catch (error) {
    return new Response(JSON.stringify({ error: String(error) }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
