import axios from 'axios'

export interface UploadResult {
  session_id: string
  total: number
  columns: string[]
  file_type: 'evtx' | 'csv'
}

export interface EventsResult {
  total: number
  page: number
  page_size: number
  records: Record<string, string>[]
}

export async function uploadFile(file: File): Promise<UploadResult> {
  const form = new FormData()
  form.append('file', file)
  const res = await axios.post<UploadResult>('/api/upload', form)
  return res.data
}

export async function fetchEvents(params: {
  session_id: string
  page: number
  page_size: number
  search: string
  sort_by: string
  sort_desc: boolean
  filters: Record<string, string>
}): Promise<EventsResult> {
  const res = await axios.get<EventsResult>('/api/events', {
    params: {
      ...params,
      filters: JSON.stringify(params.filters),
    },
  })
  return res.data
}
